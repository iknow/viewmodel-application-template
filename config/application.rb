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
    config.load_defaults 8.1
    config.active_support.cache_format_version = 7.1
    config.active_record.belongs_to_required_by_default = false

    # The Doorkeeper we currently use (5.4.0) uses redirects without :allow_other_host.
    # Remove this once we upgrade Doorkeeper.
    config.action_controller.raise_on_open_redirects = false
    config.action_controller.action_on_open_redirect = :log

    # Rails 7.1 removes autoload paths from the load path (excluding /lib). We
    # add it back so that initializers can access classes in app/lib via require
    # rather than require_dependency, thereby locking them in and preventing
    # hot-reloading from making globally cached values no longer valid.
    config.add_autoload_paths_to_load_path = true

    config.autoload_lib(ignore: %w[assets tasks generators middleware test rubo_cop web_mock])
    config.autoload_once_paths << "#{root}/app/config"

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.
    #
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.delivery_job = 'MailerJob'

    config.action_mailer.preview_paths = [Rails.root.join('spec', 'mailers', 'previews')]

    config.colorize_logging = ENV.fetch('NO_COLOR', '') == ''

    # Enable locale fallbacks for I18n (Allows lookups to fall back to the
    # I18n.default_locale when a translation cannot be found).
    # I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)

    # Rails i18n project uses zh-TW instead of zh-Hant
    # I18n.fallbacks.map(:'zh-Hant' => :'zh-TW')

    # Hide the untranslated internal Doorkeeper strings from PhraseApp
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', 'internal', '*.yml').to_s]

    config.i18n.default_locale = :en
    config.i18n.fallbacks = [
      :en,
      {
       :'zh-Hant' => [:'zh-TW', 'en'],
       :'zh-Hans' => [:'zh-CN', 'en'],
      },
    ]

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

    require_relative '../app/config/logging_config'

    config.log_level = LoggingConfig.log_level

    config.lograge.enabled = LoggingConfig.single_line_logs

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

    config.debug_exception_response_format = :api
  end
end
