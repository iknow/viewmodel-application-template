# frozen_string_literal: true

require 'loadable_config'

class B2Config < LoadableConfig
  REGION_PREFIX = 'b2/'

  attributes :default_region, :access_key_id, :secret_access_key
  attribute :inbox_bucket_name
  attribute :inbox_path_prefix, optional: true

  def inbox_region
    default_region
  end

  def client_config(region)
    region = region.delete_prefix(REGION_PREFIX)
    {
      access_key_id:,
      secret_access_key:,
      region:,
      endpoint: "https://s3.#{region}.backblazeb2.com",
      # Backblaze doesn't yet support the x-amz-checksum-crc32 checksum header
      request_checksum_calculation: 'when_required',
      response_checksum_validation: 'when_required',
    }
  end

  class << self
    delegate :inbox_region, :client_config, to: :instance
  end

  config_file 'config/app/b2.yml'
end
