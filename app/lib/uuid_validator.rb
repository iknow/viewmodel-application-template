# frozen_string_literal: true

class UuidValidator < ActiveModel::EachValidator
  UUID_REGEXP = /\A[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}\Z/i

  def validate_each(record, attribute, value)
    unless value.is_a?(String) && UUID_REGEXP.match?(value)
      record.errors.add(attribute, :bad_uuid, message: 'is not a UUID')
    end
  end
end
