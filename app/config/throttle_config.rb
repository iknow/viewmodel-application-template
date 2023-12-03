# frozen_string_literal: true

require 'loadable_config'
require 'json_schema_helper'

class ThrottleConfig < LoadableConfig
  LIMITS_SCHEMA = JsonSchemaHelper.build {
    object(
      enabled: boolean,
      period: integer,
      max_requests: integer,
      max_runtime: integer,
      max_db_runtime: integer,
    )
  }

  Limits = Value.new(:enabled, :period, :max_requests, :max_runtime, :max_db_runtime) do
    def self.load(json)
      # keys in parsed json are strings, but we want symbols
      json = json.transform_keys(&:to_sym)
      self.with(**json)
    end

    def limit_exceeded?(counters)
      # unit is seconds in config and microseconds in counters
      counters[:requests] >= max_requests ||
        counters[:runtime] >= max_runtime * 1000000 ||
        counters[:db_runtime] >= max_db_runtime * 1000000
    end
  end

  WHITELIST_SCHEMA = JsonSchemaHelper.build {
    object(
      path: array(string),
      uid: array(string),
      ip: array(string),
      token_type: array(string),
    )
  }

  Whitelist = Value.new(:path, :uid, :ip, :token_type) do
    def self.load(json)
      path = json['path'].map { |p| Regexp.new(p) }
      ip = json['ip'].map { |i| IPAddr.new(i) }
      uid = json['uid'].to_set
      token_type = json['token_type'].to_set
      self.with(path:, ip:, uid:, token_type:)
    end

    def whitelisted?(path, ip, uid, type)
      self.token_type.include?(type) ||
        self.uid.include?(uid) ||
        self.ip.any? { |cidr| cidr.include?(ip) } ||
        self.path.any? { |regex| path =~ regex }
    end
  end

  RULESET_SCHEMA = JsonSchemaHelper.build {
    object(
      path: array(string),
      authenticated: LIMITS_SCHEMA,
      unauthenticated: LIMITS_SCHEMA,
    )
  }

  Ruleset = Value.new(:path, :authenticated, :unauthenticated) do
    def self.load(json)
      path = json['path'].map { |p| Regexp.new(p) }
      authenticated = Limits.load(json['authenticated'])
      unauthenticated = Limits.load(json['unauthenticated'])
      self.with(path:, authenticated:, unauthenticated:)
    end

    def match?(path, _ip, _uid, _type)
      self.path.any? { |regex| path =~ regex }
    end
  end

  attribute :whitelist, serializer: Whitelist, schema: WHITELIST_SCHEMA

  attribute :authenticated, serializer: Limits, schema: LIMITS_SCHEMA
  attribute :unauthenticated, serializer: Limits, schema: LIMITS_SCHEMA

  attribute :custom_rulesets,
            serializer: IknowParams::Serializer::HashOf.new(IknowParams::Serializer::String, Ruleset),
            schema: JsonSchemaHelper.build { object({}, [], additional_properties: RULESET_SCHEMA) }

  attribute :dry_run, schema: JsonSchemaHelper.build { boolean }

  class << self
    delegate :whitelisted?, :dry_run?, :ruleset_for, :limits_for_ruleset, to: :instance
  end

  delegate :whitelisted?, to: :whitelist
  alias dry_run? dry_run

  def ruleset_for(path, ip, uid, type)
    name, _ruleset = custom_rulesets.detect do |_name, ruleset|
      ruleset.match?(path, ip, uid, type)
    end

    name
  end

  def limits_for_ruleset(ruleset_name)
    if ruleset_name
      ruleset = custom_rulesets.fetch(ruleset_name)
      [ruleset.authenticated, ruleset.unauthenticated]
    else
      [authenticated, unauthenticated]
    end
  end

  config_file 'config/app/throttle.yml'
end
