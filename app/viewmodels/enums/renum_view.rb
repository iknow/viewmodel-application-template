# frozen_string_literal: true

class Enums::RenumView < ViewModel
  attribute :renum_class
  lock_attribute_inheritance

  def serialize_view(json, serialize_context:)
    json.set!(ViewModel::TYPE_ATTRIBUTE, 'Type.' + renum_class.name)
    json.members renum_class.values do |renum_member|
      json.enum_constant renum_member.name
      yield(renum_member) if block_given?
    end
  end
end
