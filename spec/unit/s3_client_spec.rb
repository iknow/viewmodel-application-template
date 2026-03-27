# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'S3Client', :aws do
  let(:test_region) { 'ap-northeast-1' }
  let(:test_bucket) { 'dmm-eikaiwa-content-testing' }
  let(:client) { S3Client.new(region: test_region, bucket_name: test_bucket) }

  include UseActiveJobTestHelper

  let(:response) { aws_response }

  around(:example) do |example|
    stub_aws(response) do
      perform_enqueued_jobs do
        example.run
      end
    end
  end

  describe 'upload' do
    let(:upload_file) { Upload.build(example_media_data_url, {}) }

    let(:result) { client.upload(upload_file, filename: 'my-file') }

    context 'when AWS is down' do
      let(:response) { aws_response(put_object: 'ServiceError', head_object: aws_object_not_found_stub) }

      it 'raises an error' do
        expect { result }.to raise_error(S3Client::UploadError)
      end
    end

    context "when the object doesn't exist" do
      let(:response) { aws_response(head_object: aws_object_not_found_stub) }

      it 'uploads and returns information about the upload' do
        expect(result)
          .to have_attributes(
                filename:    'my-file',
                bucket_name: test_bucket,
                region:      test_region,
                updated:     true,
              )
      end
    end

    it 'puts the object even when already present' do
      expect(result.updated).to be true
    end

    context 'with content-addressing filenames' do
      let(:result) {
        client.upload(upload_file, filename: 'my-file', filename_addresses_content: true)
      }

      it 'does not attempt to put the object when already present' do
        expect(result.updated).to be false
      end

      context "when the object doesn't exist" do
        let(:response) { aws_response(head_object: aws_object_not_found_stub) }

        it 'puts the object' do
          expect(result.updated).to be true
        end
      end
    end

    context 'with background jobs' do
      it 'runs no background cleanup job on commit' do
        assert_performed_jobs(0) do
          ApplicationRecord.transaction do
            result
          end
        end
      end

      it 'runs a background cleanup job on rollback' do
        expect_any_instance_of(S3Client).to receive(:delete).with('my-file')
        assert_performed_jobs(1, only: S3CleanupJob) do
          ApplicationRecord.transaction do
            result
            raise ActiveRecord::Rollback.new
          end
        end
      end

      it 'aborts the cleanup job on unrecoverable errors' do
        expect_any_instance_of(S3Client).to receive(:delete).with('my-file').and_raise(S3Client::SourceMissingError.new('sentinel'))
        expect(S3CleanupJob).to receive(:warn_failed_cleanup)

        assert_performed_jobs(1, only: S3CleanupJob) do
          ApplicationRecord.transaction do
            result
            raise ActiveRecord::Rollback.new
          end
        end
      end

      it 'retries the cleanup job on recoverable errors' do
        expect_any_instance_of(S3Client).to receive(:delete).with('my-file').and_raise(S3Client::DeletionError.new('sentinel'))
        expect(S3CleanupJob).to receive(:warn_failed_cleanup).once

        assert_performed_jobs(3, only: S3CleanupJob) do
          ApplicationRecord.transaction do
            result
            raise ActiveRecord::Rollback.new
          end
        end
      end
    end
  end

  describe 'copy' do
    context 'when AWS is down' do
      let(:response) { aws_response(copy_object: 'ServiceError') }

      it 'raises an error' do
        expect {
          client.copy(from: 'a file', to: 'another-file', content_type: 'text/plain')
        }.to raise_error(S3Client::CopyError)
      end
    end

    context 'when the source is not found' do
      let(:response) { aws_response(copy_object: aws_object_not_found_stub) }
      it 'raises an error' do
        expect {
          client.copy(from: 'a file', to: 'another file', content_type: 'text/plain')
        }.to raise_error(S3Client::SourceMissingError)
      end
    end

    it 'returns details of the newly created file' do
      expect(
        client.copy(from: 'a file', to: 'another-file', content_type: 'text/plain'),
      ).to have_attributes(
             filename:    'another-file',
             bucket_name: test_bucket,
             region:      test_region,
             updated:     true,
           )
    end

    context 'with background jobs' do
      it 'runs no background cleanup job on commit' do
        assert_performed_jobs(0) do
          ApplicationRecord.transaction do
            client.copy(from: 'a file', to: 'another-file', content_type: 'text/plain')
          end
        end
      end

      it 'runs a background cleanup job on rollback' do
        expect_any_instance_of(S3Client).to receive(:delete).with('another-file')
        assert_performed_jobs(1, only: S3CleanupJob) do
          ApplicationRecord.transaction do
            client.copy(from: 'a file', to: 'another-file', content_type: 'text/plain')
            raise ActiveRecord::Rollback.new
          end
        end
      end
    end
  end

  describe 'move' do
    context 'with background jobs' do
      include UseActiveJobTestHelper
      it 'runs a background cleanup job of source on commit' do
        expect_any_instance_of(S3Client).to receive(:delete).with('a file')

        assert_performed_jobs(1, only: S3CleanupJob) do
          ApplicationRecord.transaction do
            client.move(from: 'a file', to: 'another-file', content_type: 'text/plain')
          end
        end
      end

      it 'runs a background cleanup job of destination on rollback' do
        expect_any_instance_of(S3Client).to receive(:delete).with('another-file')
        assert_performed_jobs(1, only: S3CleanupJob) do
          ApplicationRecord.transaction do
            client.move(from: 'a file', to: 'another-file', content_type: 'text/plain')
            raise ActiveRecord::Rollback.new
          end
        end
      end
    end
  end

  describe 'delete' do
    let(:result) { client.delete('my-file') }

    context 'when AWS is down' do
      let(:response) { aws_response(delete_object: 'ServiceError') }

      it 'raises an error' do
        expect { result }.to raise_error(S3Client::DeletionError)
      end
    end

    it 'deletes the file from AWS' do
      expect(result).to be_truthy
    end
  end

  describe 'presigned_url' do
    it 'returns a valid URL as string' do
      result = client.presigned_url('an object')
      expect(result).to be_a(String)
      expect { URI.parse(result) }.to_not raise_error
    end
  end

  describe '.public_url' do
    it 'returns a URL to S3' do
      expect(S3Client.public_url('region', 'bucket-name', 'file-path')).to eq \
      'https://bucket-name.s3.region.amazonaws.com/file-path'
    end

    it 'returns a URL to B2' do
      expect(S3Client.public_url('b2/region', 'bucket-name', 'file-path')).to eq \
      'https://bucket-name.s3.region.backblazeb2.com/file-path'
    end
  end

  describe '.parse_url' do
    let(:scheme) { 'https' }
    let(:port)   { 443 }
    let(:region) { 'region-name' }
    let(:bucket) { 'bucket-name' }
    let(:key)    { 'path/to/file.name' }

    let(:host) { "#{bucket}.s3.#{region}.amazonaws.com" }
    let(:path) { "/#{key}" }
    let(:uri) { URI.scheme_list[scheme.upcase].build(host:, port:, path:) }
    let(:url) { uri.to_s }

    shared_examples 'parses a url' do
      it 'parses a url in expected format' do
        expect(S3Client.parse_url(url)).to eq([region, bucket, key])
      end
    end

    shared_examples 'rejects a url' do |message|
      it 'rejects the url' do
        expect { S3Client.parse_url(url) }.to raise_error(ArgumentError, message)
      end
    end

    include_examples 'parses a url'

    context 'with bucket in the path' do
      let(:path) { "/#{bucket}/#{key}" }
      let(:host) { "s3.#{region}.amazonaws.com" }
      include_examples 'parses a url'

      context 'with hyphenated host' do
        let(:host) { "s3-#{region}.amazonaws.com" }
        include_examples 'parses a url'
      end

      context 'with missing bucket' do
        let(:key) { 'file.name' }
        let(:path) { "/#{key}" }
        include_examples 'rejects a url', /no bucket/
      end
    end

    context 'on backblaze' do
      let(:b2_region) { 'region-name' }
      let(:region) { "b2/#{b2_region}" }
      let(:host) { "#{bucket}.s3.#{b2_region}.backblazeb2.com" }
      include_examples 'parses a url'

      context 'with bucket in the path' do
        let(:path) { "/#{bucket}/#{key}" }
        let(:host) { "s3.#{b2_region}.backblazeb2.com" }
        include_examples 'parses a url'
      end
    end

    context 'with hyphenated host' do
      let(:host) { "#{bucket}.s3-#{region}.amazonaws.com" }
      include_examples 'parses a url'
    end

    context 'with the wrong scheme' do
      let(:scheme) { 'http' }
      include_examples 'rejects a url', /scheme not https/
    end

    context 'with the wrong port' do
      let(:port) { '80' }
      include_examples 'rejects a url', /port not 443/
    end

    context 'with the wrong host' do
      let(:host) { 'google.com' }
      include_examples 'rejects a url', /incorrect host/
    end
  end
end
