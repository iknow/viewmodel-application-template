# frozen_string_literal: true

Rails.application.configure do
  config.good_job.retry_on_unhandled_error = false

  # Unlike with Honeybadger's Sidekiq adapter, we don't have access to the
  # failed job here to set additional context.
  config.good_job.on_thread_error = ->(err) do
    Honeybadger.notify(err, context: { message: 'Uncaught ActiveJob error in GoodJob' })

    ViewModelLogging.log_error(e)
  end
end
