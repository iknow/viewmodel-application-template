# frozen_string_literal: true

# Builder to provide for simple customization of ActiveRecordViewModel associations.
class AssociationCustomizer
  # Mixin for ViewModel class to provide entry point
  module Customizable
    ##
    # Builder to override serialization and deserialization of the specified
    # association by defining blocks to +load+ and +dump+.
    #
    # * Parameters
    # +as+   New name for the overridden association
    # +type+ For a collection association, whether to serialize each member as:
    #          :array        - a member of an array (default)
    #          :hash         - a unique key-value pair in a hash
    #          :grouped_hash - a key-value pair forming part of a {key => [values]} hash
    # +key+  Name of attribute to uniquely identify a associated value
    #
    # * Blocks
    # +dump+          Given a viewmodel for an associated record, return the
    #                 data to serialize. Returned value must be serializable by
    #                 +ViewModel#serialize+. In the case of +hash+ or +grouped_hash+
    #                 customization, must instead return a [key,value] pair.
    #
    # +load+          Given a the data serialized by `dump`, return a view hash that
    #                 can be deserialized by the association's viewmodel.
    #
    # +view_key+      (optional) Given a dumped view for an associated record, return
    #                 a value to uniquely identify the associated value.
    #
    # +viewmodel_key+ (optional) Given a viewmodel instance for an associated
    #                 record, return a value to uniquely identify the associated
    #                 value.
    def customize_association(association_name, as: association_name, type: :array, key: nil, &block)
      ac = AssociationCustomizer.new(self, association_name, as:, type:, key:)
      ac.instance_eval(&block)
      ac.install!
    end
  end

  attr_reader :view_class, :association_name, :customized_name, :collection_type,
              :is_collection, :association_view_class, :viewmodel_key_block,
              :view_key_block

  def initialize(view_class, association_name, as: association_name, type: :array, key: nil)
    @view_class       = view_class
    @association_name = association_name
    @customized_name  = as

    unless [:array, :hash, :grouped_hash].include?(type)
      raise ArgumentError.new("Invalid collection type #{type}")
    end
    @collection_type = type

    # Fetch viewmodel class - requires non-polymorphic association
    assoc_data              = @view_class._association_data(association_name)
    @is_collection          = assoc_data.collection?
    @association_view_class = assoc_data.viewmodel_class

    if key
      viewmodel_key { |x| x.public_send(key) }
      view_key      { |x| x[key.to_s] }
    end
  end

  def viewmodel_key(&block)
    @viewmodel_key_block = block
  end

  def view_key(&block)
    @view_key_block = block
  end

  # define serialize method
  def dump(&block)
    if @is_collection
      case collection_type
      when :array
        build_array_collection_dump(&block)
      when :hash
        build_hash_collection_dump(&block)
      when :grouped_hash
        build_grouped_hash_collection_dump(&block)
      end
    else
      build_singular_dump(&block)
    end
  end

  # Define pre-parse method
  def load(&block)
    if @is_collection
      case collection_type
      when :array, :hash
        build_collection_load(&block)
      when :grouped_hash
        build_grouped_hash_collection_load(&block)
      end
    else
      build_singular_load(&block)
    end
  end

  def install!
    ac = self.freeze
    load_method = @load
    dump_method = @dump

    @view_class.instance_eval do
      define_singleton_method(:"pre_parse_#{ac.customized_name}", &load_method)
    end

    @view_class.class_eval do
      define_method(:"serialize_#{ac.association_name}", &dump_method)

      define_method(:"resolve_#{ac.association_name}") do |views, previous_viewmodels|
        existing = Array.wrap(previous_viewmodels).index_by(&ac.viewmodel_key_block)
        resolved = Array.wrap(views).map do |view|
          view_key = ac.view_key_block.call(view)
          existing.fetch(view_key) { ac.association_view_class.for_new_model }
        end
        unless ac.is_collection
          resolved = resolved.first
        end
        resolved
      end
    end
  end

  private

  def build_array_collection_dump(&block)
    ac = self
    @dump = ->(json, serialize_context:) do
      children = self.public_send(ac.association_name).map(&block)

      json.set!(ac.customized_name, children) do |child|
        ViewModel.serialize(child, json, serialize_context:)
      end
    end
  end

  def build_hash_collection_dump(&block)
    ac = self
    @dump = ->(json, serialize_context:) do
      pairs = self.public_send(ac.association_name).map(&block)

      json.set!(ac.customized_name, {}) # force the hash to exist, even if no members
      json.set!(ac.customized_name) do
        pairs.each do |k, v|
          json.set!(k) do
            ViewModel.serialize(v, json, serialize_context:)
          end
        end
      end
    end
  end

  def build_grouped_hash_collection_dump(&block)
    ac = self
    @dump = ->(json, serialize_context:) do
      pairs = self.public_send(ac.association_name).map(&block)

      groups = pairs.each_with_object({}) do |(k, v), h|
        (h[k] ||= []) << v
      end

      json.set!(ac.customized_name, {}) # force the hash to exist, even if no members
      json.set!(ac.customized_name) do
        groups.each do |k, vs|
          json.set!(k, vs) do |v|
            ViewModel.serialize(v, json, serialize_context:)
          end
        end
      end
    end
  end

  def build_singular_dump(&block)
    ac = self
    @dump = ->(json, serialize_context:) do
      json.set!(ac.customized_name) do
        child_view = block.(self.public_send(ac.association_name))
        ViewModel.serialize(block.(child_view), json, serialize_context:)
      end
    end
  end

  def build_collection_load(&block)
    ac = self
    @load = ->(viewmodel_reference, _metadata, hash, assoc_data) do
      required_type = ac.collection_type == :hash ? Hash : Array
      unless assoc_data.is_a?(required_type)
        raise ViewModel::DeserializationError::InvalidSyntax.new(
          "Invalid #{ac.customized_name}, not a #{required_type.name}: '#{assoc_data.inspect}'",
          viewmodel_reference)
      end

      views = assoc_data.map(&block)

      hash[ac.association_name.to_s] = views
    end
  end

  def build_grouped_hash_collection_load(&block)
    ac = self
    @load = ->(viewmodel_reference, _metadata, hash, assoc_data) do
      unless assoc_data.is_a?(Hash) && assoc_data.each_value.all? { |v| v.is_a?(Array) }
        raise ViewModel::DeserializationError::InvalidSyntax.new(
          "Invalid #{ac.customized_name}, not a Hash of Array values: '#{assoc_data.inspect}'",
          viewmodel_reference)
      end

      views = assoc_data.flat_map do |k, vs|
        vs.map do |v|
          block.call(k, v)
        end
      end

      hash[ac.association_name.to_s] = views
    end
  end

  def build_singular_load(&block)
    ac = self
    @load = ->(_viewmodel_reference, hash, assoc_data) do
      hash[ac.association_name.to_s] = block.(assoc_data)
    end
  end
end
