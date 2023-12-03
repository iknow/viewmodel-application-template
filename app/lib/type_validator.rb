# frozen_string_literal: true

class TypeValidator < ActiveModel::Validator
  def validate(record)
    options[:attributes].each do |attr|
      value = record.send(attr)

      validate_type_spec(record, attr, options, value, prefix: ' must be')
    end
  end

  def validate_type_spec(record, attr, options, value, prefix:)
    allow_nil = options.fetch(:allow_nil, false)

    if value.nil?
      unless allow_nil
        record.errors.add(attr, "#{prefix} not nil")
      end
    elsif (type = options[:is_a])
      unless value.is_a?(type)
        record.errors.add(attr, "#{prefix} a #{type.name}")
      end
    elsif (child_spec = options[:array_of])
      if value.is_a?(Array)
        value.each do |child|
          validate_type_spec(record, attr, child_spec, child, prefix: "#{prefix} an array whose elements are all")
        end
      else
        record.errors.add(attr, "#{prefix} an array")
      end
    elsif (key_child_spec = options[:hash_from])
      value_child_spec = options[:to]
      if value.is_a?(Hash)
        value.each do |key_child, value_child|
          validate_type_spec(record, attr, key_child_spec, key_child, prefix: "#{prefix} a hash whose keys are all")
          if value_child_spec
            validate_type_spec(record, attr, value_child_spec, value_child, prefix: "#{prefix} a hash whose values are all")
          end
        end
      else
        record.errors.add(attr, "#{prefix} a hash")
      end
    else
      raise RuntimeError.new('TypeValidator requires either :is_a or :array_of at each level')
    end
  end
end
