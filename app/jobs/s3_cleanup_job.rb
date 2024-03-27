# frozen_string_literal: true

# Asynchronous task to delete an asset on S3 after commit/rollback. Uploads are
# deleted on rollback, and the sources of S3-S3 moves are deleted on commit.
class S3CleanupJob < ApplicationJob
  queue_as :s3_cleanup

  retry_on S3Client::DeletionError, S3Client::AccessDeniedError, wait: 5.minutes, attempts: 3 do |job, err|
    warn_failed_cleanup(job, err)
  end

  discard_on S3Client::SourceMissingError do |job, err|
    warn_failed_cleanup(job, err)
  end

  def perform(region, bucket, path, _committed)
    client = Upload.s3_client_class.new(region:, bucket_name: bucket)
    client.delete(path)
  end

  def self.warn_failed_cleanup(job, err)
    region, bucket, path, committed = job.arguments
    type = committed ? 'original' : 'copied'
    action = committed ? 'commit' : 'rollback'
    message = "Upload from S3: failed to delete #{type} file after #{action}."

    context = {
      'message' => message,
      'error'   => err.message,
      'region'  => region,
      'bucket'  => bucket,
      'path'    => path,
    }

    job.report_error(err, context:)

    Rails.logger.warn(
      "#{message} " \
      "Path=#{region} / #{bucket} / #{path}. " \
      "Exception message=#{err.message}.")
  end
end
