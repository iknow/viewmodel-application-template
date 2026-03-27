# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MediaUploadService do
  let(:config_region)      { 'region' }
  let(:config_bucket_name) { 'dummy-bucket' }

  let(:cdn_prefix) { 'dummy-url-prefix' }

  # Install mocks
  let(:mock_media_config) do
    MockLoadableConfig.new(
      MediaUploadConfig,
      default_region: config_region,
      default_bucket_name: config_bucket_name)
  end

  let(:mock_cdn_config) do
    MockLoadableConfig.new(
      CdnConfig,
      cdn_domains: { [config_region, config_bucket_name] => cdn_prefix })
  end

  let_service_mock(:s3_client, 'S3Client',
                   configure_class: ->(klass) {
                     allow(klass).to receive(:same_bucket?) { |sr, sb, hr, hb| S3Client.same_bucket?(sr, sb, hr, hb) }
                   }) do |instance|
    region      = config_region
    bucket_name = config_bucket_name

    allow(instance).to receive(:upload) do |_upload_source, filename:, content_type: nil, **|
      S3Client::UploadResult.new(filename, bucket_name, region, true)
    end
  end

  before(:each) do
    allow(MediaUploadService).to receive(:config).and_return(mock_media_config)
    allow(MediaUploadService).to receive(:cdn_config).and_return(mock_cdn_config)
    allow(MediaUploadService).to receive(:s3_client_class).and_return(s3_client)
  end

  let(:path_prefix) { 'dummy-path-prefix' }
  let(:valid_content_types) { ['audio/mpeg'] }
  let(:media_type) { 'AMediaType' }

  let(:service) do
    MediaUploadService.new(region: config_region,
                           bucket_name: config_bucket_name,
                           media_type:,
                           path_prefix:,
                           valid_content_types:)
  end

  let(:example_media_file) { file_fixture('test.mp3') }
  let(:example_media_content_type) { 'audio/mpeg' }

  let(:extension) { 'mpga' }
  let(:basename)  { example_media_upload.basename_from_contents }

  shared_examples 'uploading' do
    it 'returns an expected upload result' do
      expect(result).to be_an(MediaUploadService::UploadResult)

      expect(result.region).to eq(config_region)
      expect(result.bucket_name).to eq(config_bucket_name)
      expect(result.filename).to eq("#{path_prefix}/#{basename}.#{extension}")
      expect(result.characteristics).to be_a(Hash)
    end

    it 'sets up the s3 client with the bucket' do
      expect(result).to be_present
      expect(s3_client).to have_received(:new).with(region: config_region, bucket_name: config_bucket_name)
    end

    context 'with a different compatible mime type' do
      let(:example_media_content_type) { 'audio/mp3' }
      it 'picks an appropriate extension based on MIME type' do
        expect(result.filename).to eq "#{path_prefix}/#{basename}.#{extension}"
      end
    end

    context 'with a different incompatible mime type' do
      let(:example_media_content_type) { 'audio/ogg' }

      it 'raises an error with a bad MIME type' do
        expect { result }.to raise_error(MediaUploadService::ParseError, /is not compatible with/)
      end
    end

    context 'with an empty uploaded file' do
      let(:example_media_data) { '' }

      let(:example_media_upload) do
        Upload::UploadedFile.new(example_media_uploaded_file)
      end

      it 'raises an error with a bad MIME type' do
        expect { result }.to raise_error(MediaUploadService::ParseError, /is not compatible with/)
      end
    end

    context 'with an invalid mime type' do
      let(:example_media_content_type) { 'abad1dea' }

      it 'raises an error with a bad MIME type' do
        expect { result }.to raise_error(MediaUploadService::ParseError, /is not compatible with/)
      end
    end

    context 'when uploads fail' do
      let(:s3_client_instance) do
        instance = instance_double('S3Client')
        expect(instance).to receive(:upload) { raise S3Client::UploadError }
        instance
      end

      it 'throws an error' do
        expect { result }.to raise_error(S3Client::UploadError)
      end
    end
  end

  context 'uploading' do
    let(:result) do
      service.upload(example_media_upload)
    end

    it_behaves_like 'uploading'
  end

  it 'deletes files' do
    expect(s3_client_instance).to receive(:delete).with('foobar')
    expect(service.delete('foobar')).to be_truthy
  end

  describe '.resource_url' do
    let(:region)      { config_region }
    let(:bucket_name) { config_bucket_name }

    let(:file_path) { 'file-path' }

    # The two possible outcomes -- S3 URL and rewritten, asset host URL
    let(:s3_url)    { 'some-s3-url' }
    let(:asset_url) { "#{cdn_prefix.chomp('/')}/#{file_path}" }

    let(:url) { MediaUploadService.resource_url(region, bucket_name, file_path) }

    before do
      allow(s3_client).to receive(:public_url) { s3_url }
    end

    shared_examples 'using s3' do
      it 'uses s3' do
        expect(url).to eq(s3_url)
      end
    end

    shared_examples 'using alternate url' do
      it 'uses alternate url' do
        expect(url).to eq(asset_url)
      end
    end

    context 'with no URL prefix' do
      let(:cdn_prefix) { nil }

      context 'when the region and bucket match' do
        it_behaves_like 'using s3'
      end
      context "when the region doesn't match" do
        let(:region) { 'non-matching-region' }
        it_behaves_like 'using s3'
      end
      context "when the bucket doesn't match" do
        let(:bucket_name) { 'non-matching-bucket' }
        it_behaves_like 'using s3'
      end
      context "when the region doesn't match" do
        let(:bucket_name) { 'non-matching-bucket' }
        let(:region) { 'non-matching-region' }
        it_behaves_like 'using s3'
      end
    end

    context 'with url_prefix' do
      let(:cdn_prefix) { 'https://myhost.com/assets/' }

      context 'when the region and bucket match' do
        it_behaves_like 'using alternate url'
      end
      context "when the region doesn't match" do
        let(:region) { 'non-matching-region' }
        it_behaves_like 'using s3'
      end
      context "when the bucket doesn't match" do
        let(:bucket_name) { 'non-matching-bucket' }
        it_behaves_like 'using s3'
      end
      context "when the region doesn't match" do
        let(:bucket_name) { 'non-matching-bucket' }
        let(:region) { 'non-matching-region' }
        it_behaves_like 'using s3'
      end
    end
  end
end
