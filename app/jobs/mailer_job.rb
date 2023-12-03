# frozen_string_literal: true

class MailerJob < ActionMailer::MailDeliveryJob
  # 6 attempts for a total waiting time of 20:03
  retry_on(
    StandardError,
    wait: ->(executions) { (executions**3.6) + 5 },
    attempts: 6,
  ) do |_job, err|
    # On exhausting retries, give up and notify Honeybadger
    Honeybadger.notify(err)
    ViewModelLogging.log_error(err)
  end
end
