# frozen_string_literal: true

module MediaUploading
  extend ActiveSupport::Concern

  class BadMedia < ViewModel::DeserializationError
    attr_reader :detail
    status 400
    code 'MediaUpload.BadMedia'

    def initialize(detail, nodes = [])
      @detail = detail
      super(nodes)
    end
  end

  class PathPrefixUndefined < ViewModel::DeserializationError
    status 500
    code 'MediaUpload.PathPrefixUndefined'
    detail "The upload path prefix couldn't be determined for this root node"
  end

  class InvalidInboxRegion < ViewModel::DeserializationError
    status 400
    code 'MediaUpload.InvalidInboxRegion'

    def initialize(region, required_region, nodes = [])
      @region = region
      @required_region = required_region
      super(nodes)
    end

    def detail
      "Invalid inbox upload region #{@region}, must be in #{@required_region}"
    end

    def meta
      {
        region: @region,
        required_region: @required_region,
      }
    end
  end

  class MediaUploadFailure < ViewModel::DeserializationError
    attr_reader :detail
    status 503
    code 'MediaUpload.UploadFailure'

    def initialize(detail, nodes = [])
      @detail = detail
      super(nodes)
    end
  end

  # Transform upload errors into client-facing viewmodel errors. Error handling
  # depends on a `region` field on the provided viewmodel's backing model.
  def self.wrap_upload(upload, viewmodel)
    yield
  rescue Upload::RemoteDownloadError, S3Client::AccessDeniedError, S3Client::SourceMissingError, S3Client::InvalidRegionError => e
    if upload.is_a?(Upload::Inbox) && e.is_a?(S3Client::InvalidRegionError)
      raise InvalidInboxRegion.new(upload.region, viewmodel.model.region, viewmodel.blame_reference)
    else
      raise BadMedia.new("Error accessing remote media: '#{e.message}'", viewmodel.blame_reference)
    end

  rescue S3Client::RemoteError => e
    # Unexpected S3 error not attributable to the client: error with 500
    raise MediaUploadFailure.new(e.message, viewmodel.blame_reference)
  end

  def deserialize_media_from_url(attribute, current_url, new_url, write_once: true, deserialize_context:)
    if media_url_unchanged?(attribute, current_url, new_url)
      return
    elsif write_once && current_url.present?
      raise ViewModel::DeserializationError::ReadOnlyAttribute.new(attribute, self.blame_reference)
    end

    attribute_changed!(attribute)

    if new_url.nil?
      clear_uploaded_media(attribute)
    else
      upload        = parse_upload_url(attribute, new_url, deserialize_context:)
      upload_result = upload_media(attribute, upload, deserialize_context:)
      record_uploaded_media(attribute, upload_result)
    end
  end

  def media_url_unchanged?(_attribute, current_url, new_url)
    current_url == new_url
  end

  def upload_service(_attribute, region: nil, bucket_name: nil, extra_path_prefix: nil)
    model.upload_service(region:, bucket_name:, extra_path_prefix:)
  end

  def parse_upload_url(_attribute, url, deserialize_context:)
    Upload.build(url, deserialize_context.uploaded_files, allow_remote_upload: deserialize_context.allow_remote_upload)
  rescue Upload::UploadURIError => e
    raise BadMedia.new("Invalid upload uri: #{e.message}", self.blame_reference)
  end

  def upload_media(attribute, upload, deserialize_context:, schedule_finalizer: true)
    # The root view is permitted to configure media storage for media within its owned tree
    root = deserialize_context.root? ? self : deserialize_context.nearest_root_viewmodel
    root_class = root.class

    # If a root viewmodel overrides the region and bucket, it must do so the same for all of its members.
    # This is required to let us select an inbox upload target by knowing only the root and leaf types.
    region      = root_class.media_upload_region      if root_class.respond_to?(:media_upload_region)
    bucket_name = root_class.media_upload_bucket_name if root_class.respond_to?(:media_upload_bucket_name)
    # The path prefix however may be customized on a per-view basis
    extra_path_prefix = root.media_upload_extra_path_prefix if root.respond_to?(:media_upload_extra_path_prefix)

    service = upload_service(attribute, region:, bucket_name:, extra_path_prefix:)
    MediaUploading.wrap_upload(upload, self) do
      service.upload(upload, schedule_finalizer:)
    rescue MediaUploadService::ParseError => e
      raise BadMedia.new(e.message, self.blame_reference)
    end
  end

  def record_uploaded_media(_attribute, upload_result)
    model.region      = upload_result.region
    model.bucket_name = upload_result.bucket_name
    model.filename    = upload_result.filename
  end

  def clear_uploaded_media(_attribute)
    model.region      = nil
    model.bucket_name = nil
    model.filename    = nil
  end
end
