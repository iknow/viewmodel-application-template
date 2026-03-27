# frozen_string_literal: true

require 'loadable_config'
require 'faraday_middleware/aws_sigv4'

class ElasticsearchConfig < LoadableConfig
  config_file 'config/app/elasticsearch.yml'

  attribute :host, type: :string
  attribute :prefix, type: :string, optional: true
  attribute :use_aws_authentication, type: :boolean
  attribute :username, type: :string, optional: true
  attribute :password, type: :string, optional: true
  attribute :ca_cert, type: :string, optional: true
  attribute :bulk_size, type: :integer, optional: true
  attribute :connect_timeout, type: :number
  attribute :request_timeout, type: :number
  attribute :journal, type: :boolean

  alias use_aws_authentication? use_aws_authentication

  def chewy_settings
    settings = {
      host:,
      journal:,
      transport_options: {
        request: {
          timeout: request_timeout,
          open_timeout: connect_timeout,
        },
      },
    }

    settings[:prefix] = prefix unless prefix.nil?

    if ca_cert.present?
      settings[:transport_options][:ssl] = { cert_store: ca_cert_store }
    end

    settings[:transport_options][:headers] = { content_type: 'application/json' }

    # AWS Authentication always takes precedence over Basic Auth
    if use_aws_authentication?
      settings[:transport_options][:proc] = ->(f) do
        f.request(
          :aws_sigv4,
          service:           'es',
          region:            AwsConfig.default_region,
          access_key_id:     AwsConfig.access_key_id,
          secret_access_key: AwsConfig.secret_access_key,
        )
      end
    elsif username.present? && password.present?
      settings[:transport_options][:proc] = ->(f) do
        f.request :basic_auth, username, password
      end
    end

    settings
  end

  def ca_cert_store
    @ca_cert_store ||= begin
      require 'openssl'
      store = OpenSSL::X509::Store.new
      cert = OpenSSL::X509::Certificate.new(ca_cert)
      store.add_cert(cert)
      store
    end
  end

  class << self
    delegate :chewy_settings, to: :instance
  end
end
