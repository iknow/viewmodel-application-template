# frozen_string_literal: true

class MemcachedConfig < LoadableConfig
  attribute  :servers, type: :array
  attribute  :namespace
  attributes :compress, :failover, type: :boolean
  attribute  :expires_in, type: [:integer, :null]

  config_file 'config/memcached.yml'

  def initialize
    super

    if expires_in == 0
      raise ArgumentError.new('MemcachedConfig: expires_in is set to 0; this effectively prevents caching')
    end
  end

  def rails_config
    [
      :mem_cache_store,
      *MemcachedConfig.instance.servers,
      {
        namespace:  MemcachedConfig.instance.namespace,
        expires_in: MemcachedConfig.instance.expires_in,
        compress:   MemcachedConfig.instance.compress,
        failover:   MemcachedConfig.instance.failover,
      },
    ]
  end

  class << self
    delegate :rails_config, to: :instance
  end
end
