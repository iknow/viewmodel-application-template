# frozen_string_literal: true

# Passes an uploaded file to an ActiveJob by uploading it to a S3 temporary.
# Used to allow requests including file uploads to be backgrounded.

# Note that this doesn't actually deserialize as an
# `ActionDispatch::Http::UploadedFile`, because what the BackgroundRenderingJob
# actually needs to pass to the `ActionDispatch::Integration::Session` is a
# `Rack::Test::UploadedFile`.
class UploadedFileSerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize?(arg)
    arg.is_a?(ActionDispatch::Http::UploadedFile)
  end

  def serialize(uploaded_file)
    original_filename = uploaded_file.original_filename

    # Even if the original ActionDispatch file had a null content type, we can't
    # do the same for our Rack::Test file, so we fall back to an explicit
    # application/octet-stream.
    content_type = uploaded_file.content_type || 'application/octet-stream'

    region, bucket_name, filename = S3Client.generate_inbox_location(S3Client.default_region)

    S3Client.new(region:, bucket_name:)
      .upload_file(uploaded_file.to_io, filename:, content_type:)

    hash = {
      'region' => region,
      'bucket_name' => bucket_name,
      'filename' => filename,
      'original_filename' => original_filename,
      'content_type' => content_type,
    }

    super(hash)
  end

  def deserialize(hash)
    region, bucket_name, filename, original_filename, content_type =
      hash.fetch_values('region', 'bucket_name', 'filename', 'original_filename', 'content_type')

    tempfile, _metadata = S3Client.new(region:, bucket_name:).get(filename, unlink: false)

    Rack::Test::UploadedFile.new(tempfile, content_type, true, original_filename:)
  end
end
