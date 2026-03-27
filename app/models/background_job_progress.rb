# frozen_string_literal: true

# == Schema Information
#
# Table name: background_job_progresses
#
#  id         :uuid             not null, primary key
#  error_view :jsonb
#  job_class  :string           not null, uniquely indexed => [model_id, model_type]
#  model_type :string           uniquely indexed => [job_class, model_id]
#  owner_type :string           not null
#  progress   :integer          default(0), not null
#  result     :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  model_id   :uuid             uniquely indexed => [job_class, model_type]
#  owner_id   :uuid             not null
#  status_id  :enum             default("waiting"), not null, indexed
#
# Indexes
#
#  background_job_progresses_unique_active_job   (job_class,model_id,model_type) UNIQUE WHERE ((status_id = 'active'::background_job_status) AND (model_id IS NOT NULL))
#  index_background_job_progresses_on_status_id  (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => background_job_statuses.id)
#
class BackgroundJobProgress < ApplicationRecord
  class NotWaiting < ServiceError
    status 500
    code 'BackgroundJobProgress.NotWaiting'
    detail 'The background job was not waiting to be started'
  end

  belongs_to :owner, polymorphic: true
  belongs_to :model, polymorphic: true
  belongs_to_enum :status, class_name: 'BackgroundJobStatus'

  validates :progress, numericality: { in: 0..100 }
  validates :progress, numericality: { equal_to: 0 }, if: ->(r) { r.waiting? }
  validates :progress, numericality: { equal_to: 100 }, if: ->(r) { r.complete? || r.failed? }

  validates_each :result, allow_nil: true do |record, attr, _value|
    unless record.status == BackgroundJobStatus::COMPLETE
      record.errors.add(attr, :not_failed, message: 'only complete jobs may have results')
    end
  end

  validates_each :error_view, allow_nil: true do |record, attr, value|
    unless record.status == BackgroundJobStatus::FAILED
      record.errors.add(attr, :not_failed, message: 'only failed jobs may have errors')
    end

    unless value.is_a?(Hash)
      record.errors.add(attr, :type, message: 'must be an error object')
    end
  end

  validates_all_not_null_columns!
  validates_all_string_columns!

  scope :waiting, -> { where(status_id: BackgroundJobStatus::WAITING) }
  scope :active, -> { where(status_id: BackgroundJobStatus::ACTIVE) }
  scope :complete, -> { where(status_id: BackgroundJobStatus::COMPLETE) }
  scope :failed, -> { where(status_id: BackgroundJobStatus::FAILED) }
  scope :live, -> { where(status_id: [BackgroundJobStatus::WAITING, BackgroundJobStatus::ACTIVE]) }
  scope :terminated, -> { where(status_id: [BackgroundJobStatus::COMPLETE, BackgroundJobStatus::FAILED]) }

  def self.cleanup_terminated_jobs!(older_than: 1.month)
    BackgroundJobProgress.terminated.where('updated_at < ?', older_than.ago.utc).delete_all
  end

  def rate_limit(min_progress: 10, min_time: 60.seconds, &)
    last_progress = self.progress
    last_time = Time.now.utc

    update = ->(new_progress) do
      new_time = Time.now.utc
      if new_progress > (last_progress + min_progress) || new_time > (last_time + min_time)
        last_progress = new_progress
        last_time = new_time
        self.update_progress!(new_progress)
      end
    end

    yield(update)
  end

  # Atomically set the job to active if currently waiting. If it was in any
  # other state, raise NotWaiting.
  def start!
    rows_affected = BackgroundJobProgress.connection.update(<<~SQL, nil, [BackgroundJobStatus::ACTIVE.id, BackgroundJobStatus::WAITING.id, self.id])
      UPDATE background_job_progresses SET status_id = $1 WHERE status_id = $2 AND id = $3
    SQL

    raise NotWaiting.new unless rows_affected == 1

    self.status = BackgroundJobStatus::ACTIVE
    clear_attribute_change(:status_id)
  end

  def complete!(result: nil)
    update!(status: BackgroundJobStatus::COMPLETE, progress: 100, result:)
  end

  def fail!(error_view)
    update!(status: BackgroundJobStatus::FAILED, progress: 100, error_view:)
  end

  def restart!
    update!(status: BackgroundJobStatus::WAITING, progress: 0, result: nil, error_view: nil)
  end

  def waiting?
    status == BackgroundJobStatus::WAITING
  end

  def complete?
    status == BackgroundJobStatus::COMPLETE
  end

  def failed?
    status == BackgroundJobStatus::FAILED
  end

  def terminated?
    status == BackgroundJobStatus::COMPLETE || status == BackgroundJobStatus::FAILED
  end

  # Update the progress of the background job immediately, without waiting for
  # the active transaction to complete. If the current thread's database
  # connection is already in a transaction, use a separate connection to set the
  # value immediately. To avoid the possiblity of racing, the progress is only
  # updated if the record isn't locked (to avoid contending with the
  # transaction) and it's currently below the specified value (to avoid
  # contending with other threads).
  def update_progress!(progress)
    unless ApplicationRecord.connection.transaction_open?
      self.update!(progress:)
      return
    end

    connection = ApplicationRecord.connection.pool.checkout

    connection.transaction do
      q_id = connection.quote(id)
      q_progress = connection.quote(progress)
      q_time = connection.quote(Time.now.utc)

      connection.execute(<<~SQL)
        SELECT * FROM background_job_progresses
        WHERE id = #{q_id} FOR UPDATE NOWAIT
      SQL

      result = connection.execute(<<~SQL)
        UPDATE background_job_progresses
        SET progress = #{q_progress}, updated_at = #{q_time}
        WHERE id = #{q_id} AND progress < #{q_progress}
        RETURNING progress
      SQL

      unless result.count.zero?
        # Update the AR model and flag the attribute as non-dirty
        self.progress = progress
        clear_attribute_change(:progress)
      end
    rescue ActiveRecord::LockWaitTimeout
      nil
    end
  ensure
    ApplicationRecord.connection.pool.checkin(connection) if connection
  end
end
