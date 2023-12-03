# frozen_string_literal: true

class ApplicationView < ViewModel::ActiveRecord
  self.abstract_class = true

  NEXT = 10000

  extend AssociationCustomizer::Customizable

  class MissingContextData < ViewModel::AbstractError
    status 500
    code 'ApplicationView.MissingContextData'

    def initialize(viewmodel_ref)
      @viewmodel_ref = viewmodel_ref
      super()
    end

    def detail
      "Required rendering context data missing for #{@viewmodel_ref}"
    end
  end

  # Define behaviour shared between SerializeContext and DeserializeContext as
  # modules.
  module SharedContextBase
    def initialize(request_context:, access_control:, callbacks: [], **rest)
      validate_request_context!(request_context)
      @request_context = request_context
      @view_context_data = {}
      super(access_control:, callbacks:, **rest)
    end

    attr_reader :request_context

    delegate(*RequestContext.field_names, to: :request_context)

    # Allow data required for (usually) serialization to be provided out-of-band
    # of the tree traversal. Data can be provided either as a map of a value per
    # view id (indexed) or a single value.
    def add_view_context_data(viewmodel_class, data, indexed: true)
      @view_context_data[viewmodel_class] = [indexed, data]
    end

    def has_view_context_data?(viewmodel)
      return false unless @view_context_data.has_key?(viewmodel.class)

      indexed, data = @view_context_data[viewmodel.class]
      if indexed
        data.has_key?(viewmodel.id)
      else
        true
      end
    end

    def view_context_data(viewmodel)
      unless @view_context_data.has_key?(viewmodel.class)
        raise MissingContextData.new(viewmodel.to_reference)
      end

      indexed, data = @view_context_data[viewmodel.class]

      if indexed
        data = data.fetch(viewmodel.id) do
          raise MissingContextData.new(viewmodel.to_reference)
        end
      end

      data
    end

    private

    def validate_request_context!(request_context)
      unless request_context.is_a?(RequestContext)
        raise ArgumentError.new('Invalid type for application context: '\
                                "#{request_context.inspect}")
      end

      request_context.validate_context do |errors|
        message = errors.full_messages.join('; ')
        raise ArgumentError.new("Invalid application context: #{message}")
      end
    end
  end

  module ContextBase
    delegate(*RequestContext.field_names, to: :shared_context)
    delegate :add_view_context_data, :view_context_data, :has_view_context_data?, :request_context, to: :shared_context
  end

  class DeserializeContext < ViewModel::DeserializeContext
    include ContextBase

    class SharedContext < ViewModel::DeserializeContext::SharedContext
      include SharedContextBase
    end

    def self.shared_context_class
      SharedContext
    end
  end

  def self.deserialize_context_class
    DeserializeContext
  end

  class SerializeContext < ViewModel::SerializeContext
    include ContextBase

    class SharedContext < ViewModel::SerializeContext::SharedContext
      include SharedContextBase
    end

    def self.shared_context_class
      SharedContext
    end
  end

  def self.serialize_context_class
    SerializeContext
  end

  # Customize the display of a association to many enum constants as an array of constants.
  def self.customize_enum_array_association(association_name,
                                            enum_type,
                                            as: enum_type.model_name.plural,
                                            enum_attribute_name: enum_type.model_name.singular)

    associated_viewmodel = _association_data(association_name).viewmodel_class

    customize_association(association_name, as:) do
      viewmodel_key { |vm| vm.public_send(enum_attribute_name).enum_constant }
      view_key      { |v| v[enum_attribute_name] }

      dump do |array_member_view|
        array_member_view.public_send(enum_attribute_name).enum_constant
      end

      load do |enum_constant|
        unless enum_constant.is_a?(String)
          raise ViewModel::DeserializationError::InvalidSyntax.new(
            "Invalid #{enum_attribute_name}, not a string: '#{enum_constant.inspect}'",
            self.blame_reference)
        end
        {
          ViewModel::TYPE_ATTRIBUTE => associated_viewmodel.view_name,
          enum_attribute_name => enum_constant,
        }
      end
    end
  end

  # Customize the display of an association to enum pairs as a hash from
  # constant to constant.
  def self.customize_enum_hash_association(association_name,
                                           key_enum_type,
                                           value_enum_type,
                                           key_attribute_name: key_enum_type.model_name.singular,
                                           value_attribute_name: value_enum_type.model_name.singular,
                                           as: value_attribute_name.pluralize,
                                           grouped: false)

    associated_viewmodel = _association_data(association_name).viewmodel_class

    customize_association(association_name, as:, type: (grouped ? :grouped_hash : :hash)) do
      if grouped
        # An old model can only be identified by matching the whole key/value
        # pair. A new model must be created to make a change.
        viewmodel_key do |vm|
          [
            vm.public_send(key_attribute_name).enum_constant,
            vm.public_send(value_attribute_name).enum_constant,
          ]
        end
        view_key { |v| [v[key_attribute_name], v[value_attribute_name]] }
      else
        # If it existed, the old model is uniquely identifiable by the key. This
        # allows the value for an existing key to be changed without building a
        # new record.
        viewmodel_key { |vm| vm.public_send(key_attribute_name).enum_constant }
        view_key      { |v| v[key_attribute_name] }
      end

      dump do |viewmodel|
        [
          viewmodel.public_send(key_attribute_name).enum_constant,
          viewmodel.public_send(value_attribute_name).enum_constant,
        ]
      end

      load do |key_enum_constant, value_enum_constant|
        unless key_enum_constant.is_a?(String)
          raise ViewModel::DeserializationError::InvalidSyntax.new(
            "Invalid #{key_attribute_name}, not a string: '#{key_enum_constant.inspect}'",
            self.blame_reference)
        end
        unless value_enum_constant.is_a?(String)
          raise ViewModel::DeserializationError::InvalidSyntax.new(
            "Invalid #{value_attribute_name}, not a string: '#{value_enum_constant.inspect}'",
            self.blame_reference)
        end

        {
          ViewModel::TYPE_ATTRIBUTE => associated_viewmodel.view_name,
          key_attribute_name => key_enum_constant,
          value_attribute_name => value_enum_constant,
        }
      end
    end
  end

  # Define a simple migration for added optional fields, with a down-migration
  # removing them and an empty up-migration.
  def self.migrates_adding_fields(*fields, from:, to:)
    fields = fields.map(&:to_s)

    migrates from:, to: do
      down do |view, _refs|
        fields.each { |f| view.delete(f) }
      end
      up { |_, _| }
    end
  end

  def self.null_reference
    ViewModel::Reference.new(self, nil)
  end
end
