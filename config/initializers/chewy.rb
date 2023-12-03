# frozen_string_literal: true

# Ensure that ES gem uses Typhoeus transport
require 'typhoeus'
require 'typhoeus/adapters/faraday'

Chewy.settings = ElasticsearchConfig.chewy_settings
