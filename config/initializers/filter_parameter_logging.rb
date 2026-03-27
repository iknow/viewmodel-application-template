# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.

# Parameters matching these filters should be filtered not only by Rails'
# automatic filtering but also by explicit log filtering such as when
# constructing Honeybadger contexts.
GLOBAL_PRIVACY_FILTER_PARAMETERS = [
  :password,
  :login_session_id,
  :login_secure_id,
  :access_token,
  :refresh_token,
  :authorization,
  'X-Amz-Signature',
  'X-Amz-Credential',
  /-key$/,
  # Filter URLs in keys matching 'url'
  ->(key, value) {
    next unless key =~ /(?:\A|_)url(?:_|\z)/ && value.is_a?(String)

    if value.start_with?('data:')
      value.replace('[FILTERED DATA URL]')
    elsif value.start_with?('https:')
      value.replace(ViewModelLogging.filter_url_query(value))
    end
  },
].freeze

# Configure Rails to use all the global filter parameters, in addition to ones
# that are specifically applicable to request parameters
Rails.application.config.filter_parameters += GLOBAL_PRIVACY_FILTER_PARAMETERS
Rails.application.config.filter_parameters += [
  :code,
]
