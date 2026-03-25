# frozen_string_literal: true

# A non_empty field must not be defined but empty
class NonEmptyValidator < ActiveModel::EachValidator
  def validate_each(record, attr_name, value)
    record.errors.add(attr_name, :empty, message: 'must not be empty', **options) if value&.empty?
  end
end
