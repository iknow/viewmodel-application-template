# frozen_string_literal: true

class Schemas::SchemaBaseView < ViewModel
  attribute :viewmodel_class
  delegate :model_class, to: :viewmodel_class
  lock_attribute_inheritance

  def self.inherited(child)
    # Guard against namespace mishaps: see Enums::EnumBaseView for rationale
    denested_child = child.name.split('::')[1..].join('::')
    raise "#{child} is improperly namespaced, Schemas cannot find it" unless ::Schemas.const_defined?(denested_child)

    super
  end

  def self.for_viewmodel(viewmodel_class)
    ::Schemas.const_get(viewmodel_class.name, false)
  rescue NameError
    self
  end

  def serialize_view(json, serialize_context:)
    json.set!(ViewModel::TYPE_ATTRIBUTE, 'ViewModelSchema')
    json.set!(ViewModel::VERSION_ATTRIBUTE, 3)

    json.set!('view_name', view_name)
    json.set!('view_schema_version', schema_version)
    json.set!('root', root?)

    json.members(viewmodel_members) do |member_name, member_data|
      serialize_member(json, member_name, member_data)
    end
  end

  protected

  def viewmodel_members
    viewmodel_class._members
  end

  def view_name
    viewmodel_class.view_name
  end

  def root?
    viewmodel_class.root?
  end

  def schema_version
    viewmodel_class.schema_version
  end

  def serialize_member(json, member_name, member_data, **rest)
    serialize_method = :"serialize_#{member_name}"

    if self.respond_to?(serialize_method)
      self.send(serialize_method, json, member_data, **rest)
    elsif member_data.association?
      serialize_association(json, member_name, member_data, **rest)
    else
      serialize_attribute(json, member_name, member_data, **rest)
    end
  end

  def serialize_association(json, member_name, association_data, targets: association_data.viewmodel_classes)
    json.name       member_name
    json.type       'association'
    json.viewmodels targets.map(&:view_name)
    json.external   association_data.external?
    json.referenced association_data.referenced?
    json.owned      association_data.owned?
    json.read_only  association_data.read_only?
    json.collection association_data.collection?
    json.nullable   association_nullable?(association_data)
  end

  def serialize_attribute(json, member_name, attribute_data)
    json.name       member_name
    json.type       'attribute'
    json.array      attribute_data.array?
    json.read_only  attribute_data.read_only?
    json.write_once attribute_data.write_once?
    json.nullable   model_attribute_nullable?(attribute_data.model_attr_name)

    if attribute_data.attribute_serializer
      # attribute uses a format: serializer
      json.attribute_kind 'serializer'
      json.attribute_type serializer_name(attribute_data.attribute_serializer)
    elsif attribute_data.attribute_viewmodel
      # attribute uses a viewmodel serializer
      json.attribute_kind 'viewmodel'
      json.attribute_type attribute_data.attribute_viewmodel.view_name
    else
      # Natively serialized model column
      json.attribute_kind 'native'
      json.attribute_type model_attribute_type(attribute_data.model_attr_name)
    end
  end

  def association_nullable?(association_data)
    case
    when association_data.collection?
      false
    when association_data.pointer_location == :remote
      true
    else
      # nullable if the foreign key column is
      foreign_key = association_data.direct_reflection.foreign_key
      model_attribute_nullable?(foreign_key)
    end
  end

  def model_attribute_nullable?(attribute_name)
    return nil unless model_class.respond_to?(:column_for_attribute)

    column_name =
      if (enum_attr_data = enum_attribute(attribute_name))
        enum_attr_data.foreign_key
      else
        attribute_name
      end

    column = model_class.column_for_attribute(column_name)

    # column_for_attribute always returns, even if the column doesn't exist
    return nil if column.is_a?(::ActiveRecord::ConnectionAdapters::NullColumn)

    column.null
  end

  def model_attribute_type(attribute_name)
    if (enum_attr_data = enum_attribute(attribute_name))
      return enum_attr_data.target_class.name
    end

    return nil unless model_class.respond_to?(:type_for_attribute)
    type = model_class.type_for_attribute(attribute_name)

    case
    when type.class == ::ActiveModel::Type::Value
      # we don't know anything about this attribute: maybe the column doesn't
      # exist
      nil
    when type.class == ::Types::Serializer
      # An iknow_params serializer
      serializer = type.send(:serializer)
      serializer_name(serializer)
    when type.class.module_parent == ::Types
      # One of our custom type serializers
      type.class.name
    when !type.type.nil?
      # All the Rails type serializers expose this
      type.type
    else
      # fall back to the SQL column type (if present)
      model_class.column_for_attribute(attribute_name).sql_type
    end
  end

  def serializer_name(serializer)
    serializer = serializer.class unless serializer.is_a?(Class)

    if serializer.respond_to?(:serializer_name)
      serializer.serializer_name
    else
      serializer.name
    end
  end

  def enum_attribute(attribute_name)
    if model_class.respond_to?(:belongs_to_enum_attribute)
      model_class.belongs_to_enum_attribute(attribute_name)
    end
  end
end
