# frozen_string_literal: true

# Abstract job for background actions tracked by a BackgroundJobProgress
class BackgroundJobProgressJob < ApplicationJob
  # If the job was killed by a worker process interruption, we don't want to
  # retry it: fail it here in the StandardError handler
  include GoodJob::ActiveJobExtensions::InterruptErrors

  class JobRestart < ServiceError
    status 503
    code 'BackgroundJob.JobRestarting'
    detail 'The background job requested restarting'
  end

  class JobRestartExhausted < ServiceError
    status 500
    code 'BackgroundJob.RestartLimitExceeded'
    detail 'The background job requested restarting but already reached its restart limit'
  end

  # Job cancellation is not yet implemented: this error will not yet be returned
  class JobCancelled < ServiceError
    status 499 # Client Closed Request: semi-standard code used by nginx
    code 'BackgroundJob.Cancelled'
    detail 'The background job was explicitly cancelled'
  end

  class UnexpectedResult < ServiceError
    status 500
    code 'BackgroundJob.UnexpectedResult'
    detail 'The background job failed to return a valid result'
  end

  class InvalidJobProgressState < ServiceError
    status 500
    code 'BackgroundJob.InvalidJobProgressState'
    detail 'The background job was not waiting to start'
  end

  discard_on StandardError do |job, err|
    job.final_error_handler(err)
  end

  retry_on JobRestart, wait: :polynomially_longer, attempts: 10 do |job, err|
    final_err = JobRestartExhausted.new
    job.final_error_handler(final_err)
  end

  Result = Struct.new(:body, :error) do
    def self.success(body)
      new(body, nil)
    end

    def self.failure(error)
      new(nil, error)
    end

    def successful?
      error.nil?
    end
  end

  def perform(job_progress, **job_params)
    job_progress.start!

    begin
      result = perform_background_task(job_progress, **job_params)

      raise UnexpectedResult.new unless result.is_a?(Result)

      if result.successful?
        job_progress.complete!(result: result.body)
      else
        job_progress.fail!(result.error)
      end

    rescue JobCancelled => e
      view = self.class.render_error(e)
      job_progress.fail!(view)
    rescue JobRestart
      job_progress.restart!
      raise
    end
  end

  def perform_background_task(...)
    raise 'Abstract method'
  end

  # If a job raised an unhandled error, then if if the job progress isn't
  # already terminated, record that error as its failure. Always report to
  # Honeybadger, because an unhandled error is always unexpected.
  def final_error_handler(err)
    job_progress, _ = self.arguments
    terminated_job_progress = false

    unless job_progress.terminated?
      view = BackgroundJobProgressJob.render_error(err)
      job_progress.fail!(view)
    end

    terminated_job_progress = true
  ensure
    report_error(err, context: { job_progress_id: job_progress&.id, terminated_job_progress: })
    ViewModelLogging.log_error(err)
  end

  class MultipleErrors < ViewModel::AbstractErrorCollection
    code 'BackgroundJobProgressJob.MultipleErrors'

    def detail
      "Multiple background job errors: #{cause_details}"
    end
  end

  def self.render_errors(errors)
    error = MultipleErrors.for_errors(errors)
    render_error(error)
  end

  def self.render_error(error)
    viewmodel =
      case error
      when ViewModel::AbstractError
        error.view
      else
        ViewModel::WrappedExceptionError.new(error, 500, nil).view
      end

    serialize_context = ViewModel::ErrorView.new_serialize_context(
      access_control: ViewModel::AccessControl::ReadOnly.new)

    viewmodel.serialize_to_hash(serialize_context:)
  end
end
