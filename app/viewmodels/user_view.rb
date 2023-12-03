# frozen_string_literal: true

class UserView < ApplicationView
  self.schema_version = 1
  root!

  attribute :email
  attribute :interface_language, format: ParamSerializers::Language
end
