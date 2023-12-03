# frozen_string_literal: true

require 'view_model/access_control'
require_relative 'aws_helper'

module MediaUploadHelper
  extend ActiveSupport::Concern

  include AwsHelper

  # 16x16 gif
  def example_media_file
    file_fixture('asterisk.gif')
  end

  def example_media_data
    File.binread(example_media_file)
  end

  def example_media_content_type
    'image/gif'
  end

  def example_media_content_type_extension
    MIME::Types[example_media_content_type].lazy.map(&:preferred_extension).detect(&:present?)
  end

  def example_media_data_url
    ct = ContentType.parse(example_media_content_type)
    "data:#{ct.rfc2397};base64,#{Base64.strict_encode64(example_media_data)}"
  end

  def example_media_original_filename
    'test_file'
  end

  def example_media_uploaded_file
    file = Tempfile.new('upload')
    file.binmode
    file.write(example_media_data)
    file.rewind
    Rack::Test::UploadedFile.new(file,
                                 example_media_content_type,
                                 original_filename: example_media_original_filename)
  end

  def example_media_upload
    Upload::Stream.new(StringIO.new(example_media_data), example_media_content_type)
  end

  # If we're not going through a controller test, we don't get the
  # transformation of Rack uploads into ActionDispatch uploads done for us.
  def example_media_action_dispatch_upload
    tempfile = Tempfile.new('dummy-upload')
    tempfile.binmode
    tempfile.write(example_media_data)
    tempfile.rewind

    ActionDispatch::Http::UploadedFile.new(
      {
        tempfile:,
        filename: example_media_original_filename,
        type:     example_media_content_type,
        head:     '',
      },
    )
  end

  # Stub the upload of a file that "wasn't" present in S3.
  def stub_media_upload
    stub_aws(head_object: { status_code: 404, headers: {}, body: '' }) do
      yield
    end
  end
end
