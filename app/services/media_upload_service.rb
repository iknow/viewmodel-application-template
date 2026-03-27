# frozen_string_literal: true

# MediaUploadService and subclasses are responsible for managing S3 uploads of
# content-addressed media files. Media files are partially parsed and validated
# before uploading.
class MediaUploadService
  class << self
    def s3_client_class
      S3Client
    end

    def config
      MediaUploadConfig.instance
    end

    def cdn_config
      CdnConfig.instance
    end

    def resource_url(region, bucket_name, file_path, raw: false)
      # If we're serving files in a particular bucket via a CDN, and the requested
      # file is in that bucket, create a URL to the CDN instead of directly to S3.
      cdn_prefix = cdn_config.cdn_domain(region, bucket_name)
      if !raw && cdn_prefix
        URI.join(cdn_prefix, file_path).to_s
      else
        s3_client_class.public_url(region, bucket_name, file_path)
      end
    end

    delegate :default_region, :default_bucket_name, to: :config
  end

  class ParseError < RuntimeError; end

  UploadResult = Value.new(:region, :bucket_name, :filename, :characteristics, transaction_finalizer: nil)

  attr_reader :region, :bucket_name, :path_prefix, :media_type, :valid_content_types, :randomize_filename, :always_touch

  def initialize(region: self.class.default_region, bucket_name: self.class.default_bucket_name, path_prefix: nil, media_type:, valid_content_types:, randomize_filename: false, always_touch: false)
    @region              = region
    @bucket_name         = bucket_name
    @path_prefix         = path_prefix
    @media_type          = media_type
    @valid_content_types = valid_content_types&.to_set
    @randomize_filename  = randomize_filename
    @always_touch        = always_touch
  end

  def delete(filename)
    s3_client.delete(filename)
    true
  end

  def upload(upload, schedule_finalizer: true)
    # Parse the media, potentially refining the content_type
    characteristics = characterize_media(upload)
    validate_characteristics!(upload, characteristics)
    content_type = characteristics[:content_type]

    # Derive filename from digest and extension
    basename  = pick_filename(upload)
    extension = pick_extension(content_type)
    filename  = "#{basename}.#{extension}"
    filename  = File.join(path_prefix, filename) if path_prefix

    result = s3_client.upload(
      upload,
      filename:,
      content_type:,
      metadata: { 'media_type' => media_type },
      filename_addresses_content: !randomize_filename,
      always_touch:,
      schedule_finalizer:)

    UploadResult.new(result.region, result.bucket_name, result.filename, characteristics, result.transaction_finalizer)
  end

  private

  # May be overridden in subclasses that have more accurate means of
  # characterizing a stream. Must include `content_type`, may additionally
  # include additional characteristics used by a given UploadService.
  def characterize_media(upload)
    parsed_content_type =
      begin
        FileIdentificationService.new.identify(upload.peek_range(0, 32768), upload.content_type)
      rescue ArgumentError => e
        raise ParseError.new(e.message)
      end

    {
      content_type: parsed_content_type,
    }
  end

  # May be overridden to add validations in subclasses that have additional
  # constraints. Such implementations are expected to call super.
  def validate_characteristics!(upload, characteristics)
    parsed_content_type = characteristics[:content_type]

    if valid_content_types && !valid_content_types.include?(parsed_content_type)
      raise ParseError.new(
              [
                "Invalid content type for uploaded media: '#{parsed_content_type}'",
                (" (interpreted from #{upload.content_type})" unless parsed_content_type == upload.content_type),
              ].join)
    end
  end

  def s3_client
    @s3_client ||= begin
      self.class.s3_client_class.new(region:, bucket_name:)
    end
  end

  def pick_filename(upload)
    if randomize_filename
      SecureRandom.hex(20)
    else
      upload.basename_from_contents
    end
  end

  def pick_extension(mime_type)
    extension = MIME::Types[mime_type].lazy.map(&:preferred_extension).detect(&:present?)

    if extension.nil?
      raise ParseError.new("Cannot upload media file: unknown MIME type '#{mime_type}'")
    end

    extension
  end
end
