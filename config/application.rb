# frozen_string_literal: true

require_relative 'boot'
require_relative '../lib/service_config_helper'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
# require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require 'action_mailbox/engine'
require 'action_text/engine'
require 'action_view/railtie'
require 'action_cable/engine'
# require "rails/test_unit/railtie"

require 'loadable_config'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Demoapp
  class Application < Rails::Application
    LoadableConfig.configure! do |config|
      config.config_path_prefix = Rails.root
      config.environment_key    = Rails.env

      config.preprocess { |data| ERB.new(data).result }

      config.overlay do |config_class|
        overlay_path = Rails.root.join(
          'config/app/overlays', File.basename(config_class._config_file))

        if File.readable?(overlay_path)
          YAML.safe_load_file(overlay_path, aliases: true)
        end
      end
    end

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.1
    config.active_support.cache_format_version = 7.1

    # We may require this?
    # config.add_autoload_paths_to_load_path = false

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w(assets tasks generators middleware))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.autoload_once_paths << "#{root}/app/config"

    config.action_mailer.delivery_method = :smtp
    config.action_mailer.delivery_job = 'MailerJob'

    config.action_mailer.preview_path = Rails.root.join('spec', 'mailers', 'previews')

    config.active_record.schema_format = :sql

    # Don't "normalize" `[]` to `null` in JSON parameters.
    # This is normally done to make sure you don't pass `[]` or `[nil]` to arel
    # .where(), which will convert those to SQL `IS NULL`.
    config.action_dispatch.perform_deep_munge = false

    # Don't generate system test files.
    config.generators.system_tests = nil

    config.generators do |g|
      # Use UUID primary keys by default
      g.orm :active_record, primary_key_type: :uuid

      g.test_framework :rspec, request_specs: false, fixture: false, routing_specs: false

      # Disable things we don't use
      g.assets false
      g.helper false
      g.jbuilder false
      g.template_engine nil

      # Configure the standard generators to our preferred variants
      g.resource_route      :viewmodel_api_resource_route
      g.resource_controller :viewmodel_api_controller

      # Introduce our own generators
      g.resource_viewmodel  :viewmodel_view

      # These are almost certainly a result in a weakness in my understanding
      # of hook_for, but it lets this low priority feature progress.
      g.resource_controller_spec :viewmodel_api_controller_spec
      g.resource_viewmodel_spec  :viewmodel_view_spec
    end

    config.lograge.enabled = false

    config.lograge.base_controller_class = 'ActionController::API'

    config.lograge.custom_payload do |controller|
      payload = {
        ip: controller.request.remote_ip,
      }

      if controller.respond_to?(:current_principal)
        principal = controller.current_principal

        payload[:principal_id]   = principal&.id
        payload[:principal_type] = principal&.class&.name
      end

      payload
    end
  end
end
