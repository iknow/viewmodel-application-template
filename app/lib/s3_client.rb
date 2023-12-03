# frozen_string_literal: true

require 'loadable_config'

class S3Client
  @client_cache = Concurrent::Map.new

  class << self
    def s3_config
      AwsConfig.instance
    end

    def b2_config
      B2Config.instance
    end
  end

  UploadResult = Value.new(:filename, :bucket_name, :region, :updated, transaction_finalizer: nil)

  class RemoteError          < RuntimeError; end
  class ReadError            < RemoteError; end
  class CopyError            < RemoteError; end
  class UploadError          < RemoteError; end
  class DeletionError        < RemoteError; end
  class SourceMissingError   < RemoteError; end
  class AccessDeniedError    < RemoteError; end
  class InvalidInboxUrlError < RuntimeError; end
  class InvalidRegionError   < RuntimeError; end

  class PartialDeletionError < DeletionError
    attr_reader :total, :failed_paths

    def initialize(total, failed_paths)
      @total = total
      @failed_paths = failed_paths
      message = failed_paths.map { |key, code| "#{key} => #{code}" }.join(', ')
      super("Batch deletion encountered #{failed_paths.size}/#{total} errors: #{message}")
    end
  end

  ObjectMetadata = Value.new(:etag, :content_type, :content_length, :metadata, :last_modified) do
    def self.build(s3_result)
      r = s3_result
      etag = r.etag.gsub('"', '')
      self.new(etag, r.content_type, r.content_length, r.metadata, r.last_modified)
    end
  end

  attr_reader :region, :bucket_name

  def initialize(region:, bucket_name:)
    @region = region
    @bucket_name = bucket_name
  end

  def upload(upload_source, filename:, content_type: upload_source.content_type, **args)
    if upload_source.s3_temporary?
      args = {
        from_region:  upload_source.region,
        from_bucket:  upload_source.bucket_name,
        from:         upload_source.path,
        to:           filename,
        content_type:,
        **args,
      }

      if upload_source.skip_cleanup?
        copy(**args)
      else
        move(**args)
      end
    else
      # In case the upload might be used again, ensure the stream is rewound to
      # the starting position after uploading
      upload_source.save_excursion do |stream|
        upload_file(stream, filename:, content_type:, **args)
      end
    end
  end

  def upload_file(body, filename:, content_type:, metadata: {}, filename_addresses_content: false, schedule_finalizer: true)
    obj = bucket.object(filename)
    finalizer = nil
    updated = false

    begin
      unless filename_addresses_content && obj.exists?
        obj.put(body:, content_type:, metadata:)

        updated = true
        finalizer = Upload::CreateTransactionFinalizer.new(region:, bucket: bucket_name, path: filename)
        finalizer.add_to_transaction if schedule_finalizer
      end
    rescue Aws::S3::Errors::ServiceError, Timeout::Error, Seahorse::Client::NetworkingError => e
      raise UploadError.new("S3 upload error: #{e.message}")
    end

    UploadResult.new(filename, bucket_name, region, updated, finalizer)
  end

  # Accept a file from the upload inbox and move it into place.
  def move(from_region: @region,
           from_bucket: @bucket_name,
           from:,
           to:,
           content_type: nil,
           metadata: nil,
           filename_addresses_content: false,
           schedule_finalizer: true)
    unless @region == from_region
      raise InvalidRegionError.new('S3 files can only be moved within a region')
    end

    copy_result = copy(
      from_bucket:,
      from:,
      to:,
      content_type:,
      metadata:,
      filename_addresses_content:,
      schedule_finalizer: false)

    finalizer = Upload::MoveTransactionFinalizer.new(
      create_finalizer: copy_result.transaction_finalizer,
      region:,
      source_bucket: from_bucket,
      source_path: from)

    finalizer.add_to_transaction if schedule_finalizer

    copy_result.with(transaction_finalizer: finalizer)
  end

  def copy(from_region: @region,
           from_bucket: @bucket_name,
           from:,
           to:,
           content_type: nil,
           metadata: nil,
           filename_addresses_content: false,
           schedule_finalizer: true)
    unless region == from_region
      raise InvalidRegionError.new('S3 files can only be copied within a region')
    end

    source_bucket =
      if from_bucket == bucket_name
        bucket
      else
        client.bucket(from_bucket)
      end

    begin
      if filename_addresses_content && bucket.object(to).exists?
        UploadResult.new(to, bucket_name, region, false, nil)
      else
        options = {}

        if content_type || metadata
          options[:metadata_directive] = 'REPLACE'
        end

        options[:metadata]     = metadata     if metadata
        options[:content_type] = content_type if content_type

        source_bucket.object(from).copy_to(bucket.object(to), **options)

        finalizer = Upload::CreateTransactionFinalizer.new(region:, bucket: bucket_name, path: to)
        finalizer.add_to_transaction if schedule_finalizer

        UploadResult.new(to, bucket_name, region, true, finalizer)
      end
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey => e
      raise SourceMissingError.new("S3 copy error: source missing #{from_bucket}/#{from}: #{e.message}")
    rescue Aws::S3::Errors::AccessDenied => e
      raise AccessDeniedError.new("S3 copy error: #{e.message}")
    rescue Aws::S3::Errors::ServiceError, Timeout::Error, Seahorse::Client::NetworkingError => e
      raise CopyError.new("S3 copy error #{from_bucket}/#{from} -> #{@bucket_name}/#{to}: #{e.message}")
    end
  end

  def delete(filename)
    begin
      bucket.object(filename).delete
    rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey => e
      raise SourceMissingError.new("S3 deletion error: #{e.message}")
    rescue Aws::S3::Errors::AccessDenied => e
      raise AccessDeniedError.new("S3 deletion error: #{e.message}")
    rescue Aws::S3::Errors::ServiceError, Timeout::Error, Seahorse::Client::NetworkingError => e
      raise DeletionError.new("S3 deletion error: #{e.message}")
    end
    true
  end

  def delete_multiple(filenames)
    objects = filenames.map { |f| { key: f } }
    results = bucket.delete_objects({
      delete: {
        objects:,
        quiet: true,
      },
    })
    if results.errors.empty?
      true
    else
      failed_paths = results.errors.to_h { |e| [e.key, e.code] }
      raise PartialDeletionError.new(filenames.size, failed_paths)
    end
  rescue Aws::S3::Errors::ServiceError, Timeout::Error, Seahorse::Client::NetworkingError => e
    raise DeletionError.new("S3 deletion error: #{e.message}")
  end

  def head(filename)
    head_result = bucket.object(filename).data
    ObjectMetadata.build(head_result)
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey => e
    raise SourceMissingError.new("S3 read error: #{e.message}")
  rescue Aws::S3::Errors::AccessDenied => e
    raise AccessDeniedError.new("S3 read error: #{e.message}")
  rescue Aws::S3::Errors::ServiceError, Timeout::Error, Seahorse::Client::NetworkingError => e
    raise ReadError.new("S3 read error: #{e.message}")
  end

  def get(filename)
    obj = bucket.object(filename)
    tempfile = Tempfile.new('s3-download-cache')
    tempfile.binmode

    s3_result = obj.get(response_target: tempfile.path)

    tempfile.rewind
    tempfile.unlink
    return tempfile, ObjectMetadata.build(s3_result)
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey => e
    raise SourceMissingError.new("S3 read error: #{e.message}")
  rescue Aws::S3::Errors::AccessDenied => e
    raise AccessDeniedError.new("S3 read error: #{e.message}")
  rescue Aws::S3::Errors::ServiceError, Timeout::Error, Seahorse::Client::NetworkingError => e
    raise ReadError.new("S3 read error: #{e.message}")
  end

  def read_range(filename, start, length)
    obj = bucket.object(filename)
    range = "bytes=#{start}-#{start + length - 1}"
    result = obj.get(range:)

    return result.body.read, ObjectMetadata.build(result)

  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchKey => e
    raise SourceMissingError.new("S3 read error: #{e.message}")
  rescue Aws::S3::Errors::AccessDenied => e
    raise AccessDeniedError.new("S3 read error: #{e.message}")
  rescue Aws::S3::Errors::ServiceError, Timeout::Error, Seahorse::Client::NetworkingError => e
    raise ReadError.new("S3 read error: #{e.message}")
  end

  def presigned_url(filename, method: :get, expires_in: 15.minutes)
    bucket.object(filename).presigned_url(method, expires_in: expires_in.to_i)
  end

  class << self
    def b2_region?(region)
      region.start_with?(B2Config::REGION_PREFIX)
    end

    def config_for(region)
      if b2_region?(region)
        b2_config
      else
        s3_config
      end
    end

    # instantiating an Aws::S3::Client is non-trivially expensive (~1ms), so
    # memoize them per region.
    def s3_client_for(region)
      @client_cache.compute_if_absent(region) do
        config = config_for(region)
        Aws::S3::Client.new(**config.client_config(region))
      end
    end

    def clear_client_cache!
      @client_cache.clear
    end

    def inbox_client(region)
      config = config_for(region)
      S3Client.new(region: config.inbox_region, bucket_name: config.inbox_bucket_name)
    end

    def generate_inbox_url(region, expires_in: 15.minutes)
      config = config_for(region)
      filename = "upload-#{SecureRandom.uuid}"

      if (prefix = config.inbox_path_prefix)
        filename = File.join(prefix, filename)
      end

      inbox_client(region).presigned_url(filename, method: :put, expires_in:)
    end

    def parse_inbox_url(url)
      region, bucket_name, path =
        begin
          parse_url(url)
        rescue ArgumentError => e
          raise InvalidInboxUrlError.new("Invalid upload inbox URL: #{e.message}")
        end

      config = config_for(region)

      unless region == config.inbox_region && bucket_name == config.inbox_bucket_name
        raise InvalidInboxUrlError.new("Specified URL not in inbox: #{region}/#{bucket_name}")
      end

      if config.inbox_path_prefix && !path.start_with?("#{config.inbox_path_prefix}/")
        raise InvalidInboxUrlError.new("Specified URL path not in inbox path prefix: #{path}")
      end

      [region, bucket_name, path]
    end

    def public_url(region, bucket_name, file_path)
      client = s3_client_for(region)
      Aws::S3::Object.new(bucket_name, file_path, client:).public_url
    end

    S3_HOST_REGEX = /\A(?:(?<bucket>[a-z0-9.-]+)\.)?s3[.-](?<region>[a-z0-9-]+)\.amazonaws\.com\Z/
    B2_HOST_REGEX = /\A(?:(?<bucket>[a-z0-9.-]+)\.)?s3.(?<region>[a-z0-9-]+)\.backblazeb2\.com\Z/
    PATH_REGEX = %r{\A/(?<bucket>[a-z0-9.-]+)/(?<key>.*)\Z}

    def parse_url(url)
      uri = URI(url)
      raise ArgumentError.new('Invalid S3/B2 url, scheme not https') unless uri.scheme == 'https'
      raise ArgumentError.new('Invalid S3/B2 url, port not 443')     unless uri.port   == 443

      if (host_match = S3_HOST_REGEX.match(uri.host))
        region = host_match['region']
        bucket = host_match['bucket']
      elsif (host_match = B2_HOST_REGEX.match(uri.host))
        region = B2Config::REGION_PREFIX + host_match['region']
        bucket = host_match['bucket']
      else
        raise ArgumentError.new('Invalid S3/B2 url, incorrect host')
      end

      path = uri.path

      if bucket.nil?
        # Parse a bucket specified in the path
        path_match = PATH_REGEX.match(path)
        raise ArgumentError.new('Invalid S3/B2 url, no bucket specified in path') unless path_match

        bucket = path_match['bucket']
        key    = path_match['key']
      else
        # Strip the leading slash
        key = path[1..]
      end

      [region, bucket, key]
    end

    def same_bucket?(source_region, source_bucket_name, host_region, host_bucket_name)
      source_region == host_region && source_bucket_name == host_bucket_name
    end

    delegate :default_region, to: :s3_config
  end

  private

  def client
    @client ||= Aws::S3::Resource.new(client: self.class.s3_client_for(region))
  end

  def bucket
    @bucket ||= client.bucket(bucket_name)
  end
end
