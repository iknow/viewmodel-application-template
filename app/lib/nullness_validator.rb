# frozen_string_literal: true

class NullnessValidator < ActiveModel::EachValidator
  def validate_each(record, attr_name, value)
    if requires_nil?
      record.errors.add(attr_name, :not_null, message: 'must be null') unless value.nil?
    else
      record.errors.add(attr_name, :null, message: 'must not be null') if value.nil?
    end
  end

  def requires_nil?
    options.fetch(:is_null, false)
  end
end
