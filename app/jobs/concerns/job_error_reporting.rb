# frozen_string_literal: true

# Helper for reporting job errors to honeybadger.
#
# The native honeybadger integration always reports on each failed execution. This
# module allows more control over when an error gets reported.
#
# Jobs should call `final_error_handler` in the block whenever `retry_on` or
# `discard_on` is used. This ensures the error will be reported when retries
# are exhausted and not bubble up to good job.
#
# `report_error` can also be called in a rescue block within perform if we want
# reports prior to giving up.
module JobErrorReporting
  extend ActiveSupport::Concern

  included do
    before_perform do |_job|
      # clear state, primarily breadcrumbs, from previous executions
      Honeybadger.clear!
    end
  end

  def final_error_handler(err)
    report_error(err, context: { final: true })
    ViewModelLogging.log_error(err)
  end

  def report_error(err, context: {})
    merged_context = Honeybadger::Plugins::ActiveJob.context(self).merge(context)

    Honeybadger.notify(
      err,
      context: merged_context,
      parameters: { arguments: format_argument(self.arguments) },
    )
  end

  # this converts any active models into a global id which has a more readable
  # `to_s`
  def format_argument(arg)
    case arg
    when Hash
      arg.transform_values { |value| format_argument(value) }
    when Array
      arg.map { |value| format_argument(value) }
    when GlobalID::Identification
      arg.to_global_id rescue arg
    else
      arg
    end
  end
end
