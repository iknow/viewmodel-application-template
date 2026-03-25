# frozen_string_literal: true

require 'loadable_config'

class DomainValidatorConfig < LoadableConfig
  attribute :api_scheme
  attribute :api_host
  attribute :api_port, type: :integer
  attribute :enabled, type: :boolean
  attribute :api_key, optional: true
  config_file 'config/app/domain_validator.yml'

  def api_base
    URI.scheme_list[api_scheme.upcase].build(host: api_host, port: api_port)
  end

  class << self
    delegate :api_base, to: :instance
  end
end
