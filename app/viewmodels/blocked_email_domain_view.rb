# frozen_string_literal: true

class BlockedEmailDomainView < ApplicationView
  self.schema_version = 2
  root!

  attribute :name
  attribute :automatic
  include ConstrainedTimestamps
  timestamp_attributes

  def after_deserialize(deserialize_context:, changes:)
    super if defined?(super)

    BlockedEmailDomainsIndex.import_later(model) if changes.changed_owned_tree?
  end

  migrates_adding_fields :automatic, :created_at, :updated_at, from: 1, to: 2
end
