# frozen_string_literal: true

class JsonSchemaValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    schema = options[:with]
    schema = schema.(record) if schema.is_a?(Proc)

    valid, errors = schema.validate(value)
    unless valid
      error_message = errors.map { |e| "#{e.pointer}: #{e.message}" }.join('; ')
      record.errors.add(attribute, :invalid_schema, message: error_message)
    end
  end
end
