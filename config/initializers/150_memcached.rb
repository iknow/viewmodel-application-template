# frozen_string_literal: true

config = Rails.application.config

case RailsCacheConfig.store_type
when 'mem_cache'
  config.cache_store = MemcachedConfig.rails_config
when 'memory'
  config.cache_store = :memory_store
when 'null'
  config.cache_store = :null_store
  config.action_controller.perform_caching = false
else
  raise RuntimeError.new('Unexpected store type in RailsCacheConfig')
end

# Rails creates the cache early on in initialization (rails/rails#29489), which
# means it must be created explicitly if configured in an initializer.
Rails.cache = ActiveSupport::Cache.lookup_store(*config.cache_store)

# By default, clear the cache on startup in development. We may want to retain
  # the cache at startup when for example testing invalidation or migration
  # behaviour.
if RailsCacheConfig.clear_on_startup
  Rails.application.config.after_initialize do
    Rails.cache.clear
  end
end
