# frozen_string_literal: true

require 'loadable_config'

class AwsConfig < LoadableConfig
  attributes :default_region, :access_key_id, :secret_access_key

  # A bucket in the default region which will be used for client uploads. This
  # bucket is expected to be configured as private and with a short object
  # expiration. Pre-signed URLs will be used for uploads.
  attribute :inbox_bucket_name
  attribute :inbox_path_prefix, optional: true

  config_file 'config/app/aws.yml'

  def inbox_region
    default_region
  end

  def client_config(region)
    { access_key_id:, secret_access_key:, region: }
  end

  class << self
    delegate :inbox_region, :client_config, to: :instance
  end
end
