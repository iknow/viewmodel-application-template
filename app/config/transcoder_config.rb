# frozen_string_literal: true

require 'loadable_config'

class TranscoderConfig < LoadableConfig
  attribute :transcoder_url, serializer: ParamSerializers::URI
  config_file 'config/app/transcoder.yml'
end
