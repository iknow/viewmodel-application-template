# frozen_string_literal: true

class UserView < ApplicationView
  self.schema_version = 1
  root!

  attribute :email
  attribute :name
  attribute :interface_language, format: ParamSerializers::Language

  include ConstrainedTimestamps
  timestamp_attributes
end
