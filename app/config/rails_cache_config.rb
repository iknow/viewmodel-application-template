# frozen_string_literal: true

class RailsCacheConfig < LoadableConfig
  attribute :store_type, schema: { 'enum' => ['mem_cache', 'memory', 'null'] }
  attribute :clear_on_startup, type: :boolean
  config_file 'config/app/rails_cache.yml'
end
