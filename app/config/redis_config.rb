# frozen_string_literal: true

require 'loadable_config'

# Configuration for a redis instance to be used for internal purposes by the
# backend. This may or may not be shared with other services.
class RedisConfig < LoadableConfig
  attribute :redis_url
  attribute :reconnect_attempts, type: :integer
  attribute :reconnect_delay, type: :number
  attribute :prefix

  config_file 'config/app/redis.yml'

  def redis_settings
    {
      url: redis_url,
      reconnect_attempts:,
      reconnect_delay:,
    }
  end

  def key(string)
    prefix + string
  end

  class << self
    delegate :redis_settings, :key, to: :instance
  end
end
