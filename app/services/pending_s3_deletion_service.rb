# frozen_string_literal: true

class PendingS3DeletionService
  class << self
    def s3_client_class
      S3Client
    end
  end

  def enqueue(deletions)
    PendingS3Deletion.insert_all(deletions)
  end

  MAX_RETRY_COUNT = 5

  def delete_batch(limit = 10000)
    conn = PendingS3Deletion.connection

    PendingS3Deletion
      .where(dead: false)
      .order(updated_at: :asc)
      .limit(limit)
      .pluck(:id, :region, :bucket_name, :path, :retry_count)
      .group_by do |_, region, bucket_name|
        # this should be fine as bucket_name cannot contain a /
        "#{region}/#{bucket_name}"
      end
      .each_value do |group|
        _, region, bucket_name = group[0]
        group.each_slice(1000) do |sliced_group|
          ids = sliced_group.map { |row| row[0] }

          PendingS3Deletion.transaction(requires_new: true) do
            paths = sliced_group.map { |_, _, _, path| path }

            # make the delete request
            failed_paths = {}
            partial_failure = false
            begin
              s3 = self.class.s3_client_class.new(region:, bucket_name:)
              s3.delete_multiple(paths)
            rescue S3Client::PartialDeletionError => e
              failed_paths = e.failed_paths
              partial_failure = true
            rescue S3Client::DeletionError => e
              failed_paths = paths.index_with { |path| e.message }
            end

            successful_ids = []
            failed_rows = []
            permanent_failures = []

            sliced_group.each do |id, _, _, path, retry_count|
              if failed_paths.include?(path)
                reason = failed_paths[path]

                # in a partial failure, it is less likely that the error is
                # temporary so consider everything but InternalError as permanent
                is_permanent = partial_failure && reason != 'InternalError'

                new_retry_count = retry_count + 1
                will_be_dead = is_permanent || new_retry_count >= MAX_RETRY_COUNT

                row = [id, reason, new_retry_count, will_be_dead]
                quoted_row = row.map { |value| conn.quote(value) }.join(', ')
                failed_rows.push("(#{quoted_row})")

                permanent_failures.push({ path:, reason: }) if will_be_dead
              else
                successful_ids.push(id)
              end
            end

            unless failed_rows.empty?
              update_sql = <<~SQL
                UPDATE pending_s3_deletions AS old SET
                  reason = new.reason,
                  retry_count = new.retry_count,
                  dead = new.dead,
                  updated_at = NOW() AT TIME ZONE 'utc'
                FROM (VALUES #{failed_rows.join(',')}) AS new(id, reason, retry_count, dead)
                WHERE old.id = new.id::uuid
              SQL
              conn.exec_update(update_sql)
            end
            PendingS3Deletion.delete_by(id: successful_ids)

            # report any deletions that are now permanent failures
            unless permanent_failures.empty?
              Honeybadger.notify('S3 Deletion Permanent Failure', context: {
                region:,
                bucket_name:,
                deletions: permanent_failures,
              })
            end

            Rails.logger.info("Deleted #{successful_ids.size}/#{ids.size}")
          end
        rescue NameError => e
          # do not catch typos
          raise e
        rescue StandardError => e
          update_spec = <<~SQL
            retry_count = retry_count + 1,
            dead = retry_count + 1 >= #{MAX_RETRY_COUNT},
            updated_at = NOW() AT TIME ZONE 'utc'
          SQL
          PendingS3Deletion.where(id: ids).update_all(update_spec)
          Honeybadger.notify(e)
        end
      end
    true
  end
end
