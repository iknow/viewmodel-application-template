# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PendingS3DeletionService do
  let(:region) { 'af-south-1' }
  let(:bucket_name) { 'a-bucket' }

  let_service_mock(:s3_client, 'S3Client')

  def add_chunks(paths)
    subject.enqueue(paths.map do |path|
      {
        region:,
        bucket_name:,
        path:,
      }
    end)
  end

  before(:each) do
    allow(PendingS3DeletionService).to receive(:s3_client_class).and_return(s3_client)
  end

  subject do
    PendingS3DeletionService.new
  end

  describe 'delete_batch' do
    it 'deletes successfully' do
      paths = ['a', 'b', 'c']

      expect(s3_client_instance).to receive(:delete_multiple).with(paths)

      add_chunks(paths)
      subject.delete_batch

      expect(PendingS3Deletion.count).to eq(0)
    end

    it 'increments retry count even on unexpected failure' do
      error = RuntimeError.new('TEST')
      expect(s3_client_instance).to receive(:delete_multiple).and_raise(error)
      expect(Honeybadger).to receive(:notify).once.with(error)

      add_chunks(['a'])
      begin
        subject.delete_batch
      rescue RuntimeError => e
        expect(e.message).to eq('TEST')
      end

      expect(PendingS3Deletion.count).to eq(1)

      deletion = PendingS3Deletion.first

      expect(deletion.retry_count).to eq(1)
      expect(deletion.dead).to eq(false)
    end

    it 'sets the reason on request failure' do
      error = S3Client::DeletionError.new('TEST')
      expect(s3_client_instance).to receive(:delete_multiple).and_raise(error)

      add_chunks(['a'])
      subject.delete_batch

      expect(PendingS3Deletion.count).to eq(1)

      deletion = PendingS3Deletion.first

      expect(deletion.retry_count).to eq(1)
      expect(deletion.dead).to eq(false)
      expect(deletion.reason).to eq('TEST')
    end

    it 'sets the reason on partial failure' do
      error = S3Client::PartialDeletionError.new(3, { 'a' => 'TEST', 'b' => 'InternalError' })
      expect(s3_client_instance).to receive(:delete_multiple).and_raise(error)
      expect(Honeybadger).to receive(:notify).once.with('S3 Deletion Permanent Failure', context: {
        region:,
        bucket_name:,
        deletions: [
          { path: 'a', reason: 'TEST' },
        ],
      })

      add_chunks(['a', 'b', 'c'])
      subject.delete_batch

      expect(PendingS3Deletion.count).to eq(2)

      a = PendingS3Deletion.find_by(path: 'a')
      expect(a.retry_count).to eq(1)
      expect(a.dead).to eq(true)
      expect(a.reason).to eq('TEST')

      # InternalError is not permanent
      b = PendingS3Deletion.find_by(path: 'b')
      expect(b.retry_count).to eq(1)
      expect(b.dead).to eq(false)
      expect(b.reason).to eq('InternalError')
    end

    it 'marks more than 5 retries as dead' do
      error = S3Client::DeletionError.new('TEST')
      allow(s3_client_instance).to receive(:delete_multiple).and_raise(error)
      expect(Honeybadger).to receive(:notify).once.with('S3 Deletion Permanent Failure', context: {
        region:,
        bucket_name:,
        deletions: [
          { path: 'a', reason: 'TEST' },
        ],
      })

      add_chunks(['a'])
      subject.delete_batch
      subject.delete_batch
      subject.delete_batch
      add_chunks(['b'])
      subject.delete_batch
      subject.delete_batch

      a = PendingS3Deletion.find_by(path: 'a')
      expect(a.retry_count).to eq(5)
      expect(a.dead).to eq(true)

      b = PendingS3Deletion.find_by(path: 'b')
      expect(b.retry_count).to eq(2)
      expect(b.dead).to eq(false)
    end
  end
end
