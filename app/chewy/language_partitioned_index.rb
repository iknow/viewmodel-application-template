# frozen_string_literal: true

# Implements ES's One Language Per Document pattern for a model class that
# can be partitioned by a `language_id` field. Defines an Index class for
# each Language and installs them in nested classes named by the language
# code. Each class defines a class method `primary_language`, returning its
# corresponding language. The block argument will be evaluated in the
# context of each type.
class LanguagePartitionedIndex
  include ApplicationIndex

  # Chewy's `update_index` callbacks demand that the index proc always returns a
  # valid Chewy::Index, even when the reference proc returns nil. Provide a dummy index.
  class DummyIndex < Chewy::Index
    def self.update_index(backreference, _options)
      raise ArgumentError.new('Tried to update a dummy index with real values') unless backreference.blank?
    end
  end

  class << self
    def [](language)
      @language_indexes.fetch(language) do
        raise ArgumentError.new("No partitioned index defined for '#{language}'")
      end
    end

    def each_index
      return to_enum(__method__) unless block_given?

      @language_indexes.each_value do |i|
        yield i
      end
    end

    def for_model_language(model, allow_nil: false)
      if (language = model.language)
        index = self[language]
        index
      elsif allow_nil
        DummyIndex
      else
        raise ArgumentError.new("No language defined for model #{model}")
      end
    end

    def for_model_previous_language(model)
      if (previous_language_id = model.language_id_previous_change&.first)
        language = Language[previous_language_id]
        self[language]
      else
        DummyIndex
      end
    end

    # handle importing individual models into the corresponding indexes
    def import(models)
      Array.wrap(models).group_by(&:language).each do |lang, ms|
        self[lang].import(ms)
      end
    end

    def reset!
      each_index(&:reset!)
    end

    def purge!
      each_index(&:purge!)
    end

    def purge_languages!(languages)
      languages.each do |lang|
        self[lang].purge!
      end
    end

    def reset_languages!(languages)
      languages.each do |lang|
        self[lang].reset!
      end
    end

    def settings(params = {}, &block)
      @settings_config = [params, block]
    end

    # LanguagePartitionedIndex expects the raw mapping to be provided
    # parameterized by language.
    def raw_mapping(language)
      unless @raw_mapping_proc.is_a?(Proc)
        raise RuntimeError.new("Mapping for #{self.name} is not defined. Use `define_raw_mapping` to set it on the class.")
      end

      (@raw_mappings ||= {})[language] ||= @raw_mapping_proc.call(language)
    end

    def define_language_indexes(prefix: default_prefix, scope: model_class.all, delete_if: nil, **options, &block)
      @language_indexes = Language.values.index_with do |language|
        define_language_index_class(language, prefix, scope, delete_if, options, block)
      end.freeze

      if @settings_config
        params, block = @settings_config
        each_index { |i| i.settings(params, &block) }
      end
    end

    private

    def define_language_index_class(language, prefix, scope, delete_if, options, block)
      container = self
      klass = Class.new(Chewy::Index) do
        include IndexPartition
        self.container        = container
        self.primary_language = language
        index_name("#{prefix}_#{language.code.underscore}")

        del_if =
          if delete_if
            ->(model) { model.language != language || delete_if.(model) }
          else
            ->(model) { model.language != language }
          end

        index_scope(scope.where(language_id: primary_language.id), delete_if: del_if, **options)

        instance_exec(&block)
      end

      constant_name = language.code.underscore.camelize + 'Index'
      const_set(constant_name, klass)

      klass
    end

    def default_prefix
      # ES index names can't include `/`
      self.name.underscore.gsub('/', '~').gsub(/_index(es)?$/, '')
    end
  end

  # Each index partition delegates back to its container for model, view and
  # mapping
  module IndexPartition
    extend ActiveSupport::Concern
    include ApplicationIndex

    class_methods do
      attr_accessor :container, :primary_language
      delegate :model_class, :view_class, :raw_mapping, to: :container

      def mappings_hash
        { mappings: raw_mapping(primary_language) }
      end
    end
  end
end
