# frozen_string_literal: true

class LoggingConfig < LoadableConfig
  LOG_LEVELS = ['debug', 'info', 'warn', 'error', 'fatal', 'unknown'].freeze

  attribute :log_level, schema: { 'enum' => LOG_LEVELS }

  attribute :single_line_logs, type: :boolean

  config_file 'config/app/logging.yml'
end
