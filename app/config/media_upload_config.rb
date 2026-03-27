# frozen_string_literal: true

require 'loadable_config'

class MediaUploadConfig < LoadableConfig
  attribute :default_region
  attribute :default_bucket_name
  attribute :url_prefix, optional: true

  config_file 'config/app/media.yml'
end
