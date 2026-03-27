# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ImageUploadService do
  let(:config_region)      { 'region' }
  let(:config_bucket_name) { 'dummy-bucket' }
  let(:config_url_prefix)  { 'dummy-url-prefix' }

  let(:mock_media_config) do
    MockLoadableConfig.new(
      MediaUploadConfig,
      default_bucket_name: config_bucket_name,
      url_prefix: config_url_prefix)
  end

  let_service_mock(:s3_client, 'S3Client') do |instance|
    region      = config_region
    bucket_name = config_bucket_name
    allow(instance).to receive(:upload) do |upload_source, filename:, content_type: nil, **rest|
      S3Client::UploadResult.new(filename, bucket_name, region, true)
    end
  end

  before(:each) do
    allow(MediaUploadService).to receive(:config).and_return(mock_media_config)
    allow(MediaUploadService).to receive(:s3_client_class).and_return(s3_client)
  end

  let(:path_prefix) { 'dummy-path-prefix' }
  let(:valid_content_types) { ['image/jpeg'] }
  let(:media_type) { 'AMediaType' }

  let(:service) do
    ImageUploadService.new(region: config_region,
                           bucket_name: config_bucket_name,
                           media_type:,
                           path_prefix:,
                           valid_content_types:)
  end

  let(:example_media_file) { file_fixture('test.jpg') }
  let(:example_media_content_type) { 'image/jpeg' }
  let(:basename) { example_media_upload.basename_from_contents }

  it 'uploads as expected' do
    result = service.upload(example_media_upload)

    expected_filename = "#{path_prefix}/#{basename}.jpeg"

    expect(result.filename).to    eq expected_filename
    expect(result.bucket_name).to eq config_bucket_name
    expect(result.region).to      eq config_region
    expect(result.characteristics).to include(dimensions: ActiveRecord::Point.new(300, 300))
  end

  describe 'characteristics' do
    let(:characteristics) { service.characterize_media(example_media_upload) }

    it 'can match media with specified mime type' do
      expect(characteristics).to include(content_type: example_media_content_type)
    end

    it 'can identify image dimensions' do
      expect(characteristics).to include(dimensions: ActiveRecord::Point.new(300, 300))
    end

    context 'without specified mime type' do
      let(:example_media_content_type) { nil }
      it 'can identify content_type from the media' do
        expect(characteristics).to include(content_type: 'image/jpeg')
      end
    end

    context 'with mismatching mime type' do
      let(:example_media_content_type) { 'image/png' }

      it 'infers the correct content_type from the media' do
        expect(characteristics).to include(content_type: 'image/jpeg')
      end
    end

    context 'with an unparseable image' do
      let(:example_media_data) { "\x0F" }

      it 'raises an error' do
        expect { characteristics }.to raise_error(ImageUploadService::ParseError)
      end
    end
  end
end
