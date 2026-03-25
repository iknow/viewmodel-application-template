# frozen_string_literal: true

class MetadataFieldNameValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value.is_a?(String) && MetadataField::VALID_NAME.match?(value)
      message = options.fetch(:message, "is not a valid metadata field name ('#{value}')")
      record.errors.add(attribute, :invalid_metadata_field_name, message:)
    end
  end
end
