# frozen_string_literal: true

# Common behavior for indexes. Chewy doesn't permit this to be a base class.
module ApplicationIndex
  extend ActiveSupport::Concern

  # Unspecified languages will use the "standard" analyzer.
  LANGUAGE_ANALYZERS = {
    Language::DE      => 'german',
    Language::EN      => 'english',
    Language::ES      => 'spanish',
    Language::FR      => 'french',
    Language::JA      => 'kuromoji',
    Language::KO      => 'cjk', ## No specialized Korean analyzer
    Language::ZH_HANS => 'smartcn',
    Language::ZH_HANT => 'smartcn',
  }.freeze

  EMAIL_ANALYZER_SETTINGS = {
    filter: {
      email_pattern: {
        type: 'pattern_capture',
        preserve_original: false,
        patterns: [
          '([^@]+)',
          '([\\p{L}\\d]+)',
          '@(.+)',
          '([^-@]+)',
        ],
      },
    },
    analyzer: {
      email_pattern: {
        tokenizer: 'uax_url_email',
        filter: ['email_pattern', 'unique', 'lowercase'],
      },
    },
  }.freeze

  AfterTransactionImporter = Struct.new(:index, :model_ids) do
    include ViewModel::AfterTransactionRunner

    def after_commit
      ElasticsearchImportJob.perform_later(index.name, model_ids)
    end

    def connection
      index.model_class.connection
    end
  end

  class_methods do
    def model(model_class)
      @model_class = model_class
    end

    def model_class
      unless @model_class.is_a?(Class) && @model_class < ActiveRecord::Base
        raise RuntimeError.new("Model for #{self.name} is not set to an ActiveRecord mode. Use `model ModelClass` to set it on the class")
      end

      @model_class
    end

    def view(view_class)
      @view_class = view_class
    end

    def view_class
      unless @view_class.is_a?(Class) && @view_class < ViewModel
        raise RuntimeError.new("View for #{self.name} is not set to an ActiveRecord mode. Use `view ViewClass` to set it on the class")
      end

      @view_class
    end

    def import_with_lock(*models)
      model_class.transaction do
        # Chewy will always re-fetch the models, no advantage in loading them
        # here. Obtain locks in id order to avoid deadlock.
        model_class.lock("FOR SHARE OF #{model_class.table_name}").where(id: models.sort).order(:id).pluck(:id)

        # Pass through original `models` to allow Chewy to handle deletions
        import(*models)
      end
    end

    def import_later(*models)
      model_ids = models.map do |m|
        case m
        when String
          m
        when ActiveRecord::Base
          m.id
        else
          raise ArgumentError.new("Unexpected non-model: #{m.inspect}")
        end
      end

      AfterTransactionImporter.new(self, model_ids).add_to_transaction
    end

    def define_raw_mapping(&block)
      @raw_mapping_proc = block
    end

    # Calculates and memoizes the raw mapping using the block defined by
    # `define_raw_mapping`. Can be overridden in subclasses to allow mappings to
    # be parameterized and varied across related indexes, for example for
    # changing primary language analyzers.
    def raw_mapping
      unless @raw_mapping_proc.is_a?(Proc)
        raise RuntimeError.new("Mapping for #{self.name} is not defined. Use `define_raw_mapping` to set it on the class.")
      end
      @raw_mapping ||= @raw_mapping_proc.call
    end

    def index_scope(scope = model_class.all, **options)
      default_import_options bulk_size: ElasticsearchConfig.bulk_size

      crutch :views do |collection|
        render_views(collection)
      end

      super
    end

    # Manually define the ElasticSearch mapping. Chewy does not expose a
    # standard mechanism to override mappings, however the result of
    # #mappings_hash (usually computed from `field`s defined in Chewy's DSL)
    # is passed directly to ES.
    def mappings_hash
      { mappings: raw_mapping }
    end

    def view_root(&block)
      root type: 'object', value: ->(model, crutches) do
        view = crutches.views[model.id]
        block.call(model, view, crutches)
      end
    end

    def render_views(collection)
      views = collection.map { |m| view_class.new(m) }
      ctx = view_class.new_serialize_context

      ViewModel.preload_for_serialization(views)
      views.each_with_object({}) do |view, h|
        h[view.id] = ViewModel.serialize_to_hash(view, serialize_context: ctx)
      end
    end

    protected

    # ElasticSearch mapping for a string in a particular natural language.
    def language_string_mapping(language)
      mapping = {
        type: 'text', analyzer: LANGUAGE_ANALYZERS.fetch(language, 'standard'),
        fields: {
          raw: { type: 'keyword' },
        }
      }

      # Don't use the standard analzyer for certain languages, such as Japanese and Chinese, because
      # it breaks the query into very small/common tokens causing almost all content to be matched.
      unless language.ideographic
        mapping[:fields][:standard] = { type: 'text', analyzer: 'standard' }
      end

      mapping
    end

    # ElasticSearch mapping for an object containing a repeated structure
    # keyed by language
    def multi_language_mapping(exclude: nil)
      {
        properties: Language.values.each_with_object({}) do |lang, h|
          next if lang == exclude
          h[lang.code] = yield(lang)
        end,
      }
    end

    # ElasticSearch mappings for a string in many languages
    def multi_language_string_mapping(exclude: nil)
      multi_language_mapping(exclude:) do |lang|
        language_string_mapping(lang)
      end
    end

    # ElasticSearch mappings for a string and its translations
    def translated_string_mappings(field_name, primary_language:)
      {
        field_name                   => language_string_mapping(primary_language),
        "#{field_name}_translations" => multi_language_string_mapping(exclude: primary_language),
      }
    end
  end
end
