# frozen_string_literal: true

# We want to eager-load LoadableConfig singleton instances to ensure that the
# configuration typechecks before launching the application. This is of particular
# use in production and test environments with `config.eager_load = true`.
Rails.autoloaders.once.on_load do |_name, clazz, _path|
  clazz.instance if clazz < LoadableConfig
end
