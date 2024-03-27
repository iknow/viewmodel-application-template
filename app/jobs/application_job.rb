# frozen_string_literal: true

class ApplicationJob < ActiveJob::Base
  include JobErrorReporting

  # Keeps track of whether we've notified on an error for this execution. This
  # can happen when reporting errors from `perform` since we also report errors
  # in the final `retry_on` or `discard_on`.
  attr_accessor :reported_error

  before_perform do |job|
    job.reported_error = false
  end

  # fallback error handler, if no retry behavior is defined, then report the
  # error and discard it to prevent bubbling up to the goodjob handler which
  # should handle truly exceptional errors
  #
  # note that `final_error_handler` will still need to be called whenever
  # `retry_on` or `discard_on` is used as errors do not cascade down handlers
  discard_on StandardError do |job, error|
    job.final_error_handler(error)
  end

  def report_error(...)
    return if @reported_error

    @reported_error = true

    super
  end
end
