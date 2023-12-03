# frozen_string_literal: true

class Enums::EnumBaseView < ViewModel
  attribute :enum_class
  lock_attribute_inheritance

  @enum_views = {}

  def self.inherited(child)
    # This guard prevents a difficult-to-detect bug where a subclass, due to namespace mishaps, will not be found by
    # `for_model` when Rails autoloading is disabled (e.g. production). For example:
    #
    # module Rtc; end
    # module Enums
    #   class Rtc::MyEnumView < EnumBaseView
    #   end
    # end
    #
    # Here, `MyEnumView` will become a constant of `Rtc`, and not `Enums`. `for_model` will not be able to find the
    # view class and will fall back to the default, which could unwantedly expose or not expose enum metadata. To fix
    # this issue, instead write:
    #
    # module Rtc; end
    # module Enums
    #   module Rtc
    #     class MyEnumView < EnumBaseView
    #     end
    #   end
    # end
    #
    # Assumes Enums is a top-level namespace
    denested_child = child.name.split('::')[1..-1].join('::')
    raise "#{child} is improperly namespaced, Enums cannot find it" unless Enums.const_defined?(denested_child)

    super
  end

  # Resolve the enum view for the specified model, if present, otherwise return
  # an appropriate base view
  def self.for_model(enum_model)
    Enums.const_get(enum_model.name + 'View', false)
  rescue NameError
    case
    when enum_model < Renum::EnumeratedValue
      ::Enums::RenumView
    when enum_model < PersistentEnum::ActsAsEnum
      ::Enums::EnumBaseView
    else
      raise ArgumentError.new("Cannot infer base view type for model class #{enum_model.inspect}")
    end
  end

  def serialize_view(json, serialize_context:)
    json.set!(ViewModel::TYPE_ATTRIBUTE, 'Type.' + enum_class.name)
    json.members enum_class.values do |member|
      json.enum_constant member.enum_constant
      serialize_enum_attributes(json, member, serialize_context:)
    end
  end

  protected

  def enum_attributes
    enum_class.attribute_names - ['id', enum_class.name_attr.to_s]
  end

  def serialize_enum_attributes(json, member, serialize_context:)
    json.extract!(member, *enum_attributes)
  end
end
