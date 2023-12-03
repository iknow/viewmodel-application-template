# frozen_string_literal: true

require 'loadable_config'

class SmtpConfig < LoadableConfig
  config_file 'config/app/smtp.yml'

  attribute :perform_deliveries, type: :boolean, optional: true, default: true
  attribute :host, type: :string
  attribute :port, type: :integer, optional: true
  attribute :username, type: :string, optional: true
  attribute :password, type: :string, optional: true
  attribute :authentication, schema: { 'enum' => ['plain', 'login', 'cram_md5'].freeze }, optional: true
  attribute :enable_starttls_auto, type: :boolean, optional: true
  attribute :ses_configuration_set, type: :string, optional: true
  attribute :ses_bounce_topics, type: :array, schema: { 'items' => { 'type' => 'string' } }, optional: true, default: []

  def smtp_settings
    {
      address: host,
      port:,
      user_name: username,
      password:,
      authentication: authentication&.to_sym,
      enable_starttls_auto:,
    }.compact
  end

  class << self
    delegate :smtp_settings, to: :instance
  end
end
