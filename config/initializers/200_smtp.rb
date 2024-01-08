# frozen_string_literal: true

if SmtpConfig.perform_deliveries
  Rails.application.config.action_mailer.perform_deliveries = true
  Rails.application.config.action_mailer.smtp_settings = SmtpConfig.smtp_settings
end
