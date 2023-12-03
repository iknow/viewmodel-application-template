# frozen_string_literal: true

# We support three types of upload source, each of which are specified as a URI:
# * https: URI of a resource uploaded to our s3 inbox
# * inline data: uri
# * mime multipart content-id cid: URI
class Upload
  class << self
    def s3_client_class
      S3Client
    end
  end

  class UploadURIError < ArgumentError; end

  class InvalidURI < UploadURIError
    def initialize(uri)
      super()

      @uri = uri
    end

    def message
      "Invalid upload uri: #{@uri}"
    end
  end

  class MissingCID < UploadURIError
    attr_reader :cid

    def initialize(cid)
      super()

      @cid = cid
    end

    def message
      "No multi-part upload with Content-ID: #{cid}"
    end
  end

  class InvalidRemoteHost < UploadURIError
    def initialize(host)
      super()

      @host = host
    end

    def message
      "Remote host not in upload whitelist: '#{@host}'"
    end
  end

  class RemoteDownloadError < RuntimeError; end

  REMOTE_FILE_HOST_WHITELIST = [
  ].to_set.freeze

  def self.build(url, multipart_uploads)
    # URI(url) is not performant when url is > 10mb.  We don't want to support
    # this, but making this work in the client is much more effort.
    # https://github.com/iknow/issues/issues/17
    if url.starts_with?('data:')
      data, content_type =
        begin
          parse_data_url(url)
        rescue ArgumentError
          raise InvalidURI.new(url[0..128])
        end

      return Upload::Inline.from_string(data, content_type)
    end

    uri = URI(url)

    case uri.scheme
    when 'cid'
      cid  = uri.opaque
      file = multipart_uploads[cid]
      raise MissingCID.new(cid) unless file

      Upload::UploadedFile.new(file)
    when 'https'
      begin
        Upload::Inbox.new(uri)
      rescue S3Client::InvalidInboxUrlError
        Upload::RemoteFile.new(uri)
      end
    else
      raise InvalidURI.new(uri)
    end

  rescue URI::InvalidURIError
    raise InvalidURI.new(uri)
  end

  def s3_temporary?
    false
  end

  def peek_range(start, length)
    save_excursion do
      stream.seek(start, IO::SEEK_SET)
      buf = +''
      stream.read(length, buf)
      buf
    end
  end

  def basename_from_contents
    BaseX::Base62DUL.encode(approximate_digest)
  end

  def self.parse_data_url(url)
    raise ArgumentError.new('Not a data url') unless url.starts_with?('data:')

    # Require the comma to be within the first 128 characters of the string.
    comma = url[0, 128].index(',')
    raise ArgumentError.new('Missing comma in data url') unless comma

    metadata = url[5...comma]
    data = url[comma + 1..] # this is expected to share the tail (unchecked)

    base64_flag = false
    explicit_encoding = nil
    explicit_content_type = nil

    mediatype, *params = metadata.split(';')

    if mediatype && mediatype != ''
      explicit_content_type = mediatype
    end

    if params.last == 'base64'
      base64_flag = true
      params.pop
    end

    params.each do |raw_param|
      key, raw_value = raw_param.split('=', 2)
      value = URI::DEFAULT_PARSER.unescape(raw_value)

      case key
      when 'charset'
        explicit_encoding = Encoding.find(value)
      end
    end

    data = if base64_flag
             Base64.decode64(data)
           else
             URI::DEFAULT_PARSER.unescape(data)
           end

    # The RFC states that mediatype defaults to "text/plain;charset=US-ASCII".
    # We consider this atomic, so if we've parsed a content type we use the
    # explicit encoding or default to an opaque string (ASCII-8BIT in ruby).
    # An explicit encoding always wins, in an attempt to support the claim from
    # the rfc:
    #
    # > As a shorthand, "text/plain" can be omitted but the charset parameter
    # > supplied..

    encoding = explicit_encoding || (explicit_content_type ? Encoding::ASCII_8BIT : Encoding::US_ASCII)

    data.force_encoding(encoding) if encoding

    return data, explicit_content_type || 'text/plain'
  end

  def save_excursion
    pos = stream.pos
    yield(stream)
  ensure
    stream.seek(pos, IO::SEEK_SET)
  end

  private

  # For the purposes of best-effort upload deduplication, we want to be able to
  # name files by a hash of their contents. This won't always be possible,
  # particularly in the case of multi-part uploaded S3 inbox files, but we at
  # least have a guarantee that the same file uploaded in the same way will have
  # the same digest. Since our use of this is purely for saving S3 space, this
  # is acceptable.
  def approximate_digest
    @approximate_digest ||=
      begin
        digest = Digest::MD5.new
        stream = self.stream
        buf = +''
        save_excursion do
          while stream.read(16384, buf)
            digest.update(buf)
          end
        end
        digest.digest!
      end
  end
end

class Upload::Stream < Upload
  attr_reader :stream, :content_type

  def initialize(stream, content_type)
    super()

    @stream = stream
    @content_type = content_type
  end
end

class Upload::Inline < Upload::Stream
  def self.from_uri(uri)
    self.new(StringIO.new(uri.data), uri.content_type)
  end

  def self.from_string(string, content_type)
    self.new(StringIO.new(string), content_type)
  end
end

class Upload::RemoteFile < Upload::Stream
  def initialize(uri, headers: {}, allowed_hosts: REMOTE_FILE_HOST_WHITELIST)
    unless allowed_hosts == :any || allowed_hosts.include?(uri.host)
      raise InvalidRemoteHost.new(uri.host)
    end

    tempfile, content_type = download_file(uri, headers)

    super(tempfile, content_type)
  end

  private

  def download_file(uri, headers)
    tempfile = Tempfile.new('remote-download-cache')
    tempfile.binmode
    content_type = nil

    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Get.new(uri, headers)
      http.request(request) do |response|
        content_type = response.content_type
        response.read_body do |chunk|
          unless response.is_a?(Net::HTTPSuccess)
            raise RemoteDownloadError.new("Remote download failed with response code: #{response.code}")
          end

          tempfile.write(chunk)
        end
      end
    end

    tempfile.rewind

    return tempfile, content_type

  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
         Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
    raise RemoteDownloadError.new(e.message)
  ensure
    tempfile&.unlink
  end
end

# An ActionDispatch::HTTP::UploadedFile
class Upload::UploadedFile < Upload::Stream
  attr_reader :uploaded_file

  # Reopen the tempfile as a separate file descriptor, so that the read pointer
  # isn't shared with anything else that's using the same ActionDispatch
  # UploadedFile.
  def initialize(uploaded_file)
    @uploaded_file = uploaded_file
    new_io = File.open(uploaded_file.tempfile)
    new_io.binmode if uploaded_file.tempfile.binmode?

    super(new_io, uploaded_file.content_type)
  end
end

class Upload::S3Temporary < Upload
  attr_reader :region, :bucket_name, :path

  def s3_temporary?
    true
  end

  def skip_cleanup?
    false
  end

  def initialize(region, bucket_name, path)
    super()

    @region      = region
    @bucket_name = bucket_name
    @path        = path
  end

  def content_type
    return @content_type if @content_type

    s3_metadata = s3_client.head(path)
    save_metadata(s3_metadata)
    @content_type
  end

  def approximate_digest
    return @approximate_digest if @approximate_digest

    s3_metadata = s3_client.head(path)
    save_metadata(s3_metadata)
    @approximate_digest
  end

  def content_length
    return @content_length if @content_length

    s3_metadata = s3_client.head(path)
    save_metadata(s3_metadata)
    @content_length
  end

  def stream
    @stream ||=
      begin
        tempfile, s3_metadata = s3_client.get(path)
        save_metadata(s3_metadata)
        tempfile
      end
  end

  def peek_range(start, length)
    # If we've already downloaded the file then use it, otherwise fetch the range
    return super if @stream

    bytes, s3_metadata = s3_client.read_range(path, start, length)
    save_metadata(s3_metadata)
    bytes
  end

  private

  def s3_client
    @s3_client ||= self.class.s3_client_class.new(region:, bucket_name:)
  end

  def save_metadata(s3_metadata)
    @approximate_digest = BaseX::Base16.decode(s3_metadata.etag.downcase)
    @content_type       = s3_metadata.content_type
    @content_length     = s3_metadata.content_length
  end
end

class Upload::Inbox < Upload::S3Temporary
  def initialize(uri)
    region, bucket_name, path = self.class.s3_client_class.parse_inbox_url(uri)
    super(region, bucket_name, path)
  end

  # Inbox buckets have an aggressive auto-delete policy
  def skip_cleanup?
    true
  end
end

# Transactional finalizer for files created by an upload or copy: removes the
# uploaded asset on rollback.
class Upload::CreateTransactionFinalizer
  include ViewModel::AfterTransactionRunner

  def initialize(region:, bucket:, path:)
    @region = region
    @bucket = bucket
    @path   = path
  end

  def after_rollback
    S3CleanupJob.perform_later(@region, @bucket, @path, false)
  end
end

# Transactional finalizer for S3-S3 moves: in addition to rollback cleanup of
# the destination (delegated to an Create finalizer), removes the source asset
# on commit.
class Upload::MoveTransactionFinalizer
  include ViewModel::AfterTransactionRunner

  def initialize(create_finalizer:, region:, source_bucket:, source_path:)
    @create_finalizer = create_finalizer
    @region        = region
    @source_bucket = source_bucket
    @source_path   = source_path
  end

  def after_commit
    S3CleanupJob.perform_later(@region, @source_bucket, @source_path, true)
  end

  def after_rollback
    @create_finalizer&.after_rollback
  end
end
