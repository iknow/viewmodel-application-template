# frozen_string_literal: true

class RenumSerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize?(arg)
    arg.is_a?(Renum::EnumeratedValue)
  end

  def serialize(enum_value)
    super({
            'class' => enum_value.class.name,
            'name'  => enum_value.name,
          })
  end

  def deserialize(hash)
    enum_class_name = hash.fetch('class')
    enum_class = enum_class_name.safe_constantize

    unless enum_class < Renum::EnumeratedValue
      raise ArgumentError.new("Invalid enum class #{enum_class_name}")
    end

    name       = hash.fetch('name')
    enum_value = enum_class.with_name(name)

    unless enum_value
      raise ArgumentError.new("Invalid enum member #{name}")
    end

    enum_value
  end
end
