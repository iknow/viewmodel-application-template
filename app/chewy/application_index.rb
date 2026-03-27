# frozen_string_literal: true

# Common behavior for indexes. Chewy doesn't permit this to be a base class.
module ApplicationIndex
  extend ActiveSupport::Concern

  # Unspecified languages will use the "standard" analyzer.
  LANGUAGE_ANALYZERS = {
    Language::EN      => 'english',
    Language::JA      => 'kuromoji',
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

  # After commit, launches a background job to import the supplied models.
  # Models may be supplied either as AR objects or as ids.
  AfterTransactionImporter = Struct.new(:index, :models, :finalized) do
    include ViewModel::AfterTransactionRunner

    def initialize(index, models)
      super(index, models, false)
    end

    def add_models(new_models)
      raise RuntimeError.new('Attempted to add models to a finalized AfterTransactionImporter') if finalized

      models.concat(new_models)
    end

    def import!
      model_ids = Set.new

      models.each do |m|
        id = case m
             when String, Integer
               m
             when ActiveRecord::Base
               raise ArgumentError.new("Unpersisted model: #{m.inspect}") unless m.id

               m.id
             else
               raise ArgumentError.new("Unexpected non-model: #{m.inspect}")
             end

        model_ids << id
      end

      ElasticsearchImportJob.perform_later(index.name, model_ids.to_a)
    end

    def after_commit
      self.finalized = true
      import!
    end

    def after_rollback
      self.finalized = true
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

    # Chewy by default reimports the entire index if given no models. This is a
    # footgun we want no part of: we prefer that importing nothing will do
    # nothing. However, we want to make the exception that if you're explicitly
    # providing Chewy options (which we typically don't) then that's a sign that
    # you want Chewy's exact behaviour -- even if those options are empty. This
    # means that Chewy's rake tasks can safely use #import with the behaviour
    # they expect of it.
    def includes_no_models_and_options?(models)
      return true if models.empty?
      return true if models.all? { |m| m.is_a?(Array) && includes_no_models_and_options?(m) }

      false
    end

    def import(*models)
      if includes_no_models_and_options?(models)
        # Additionally, we don't expect to hit this directly, because in all our
        # actual use-cases we're using #import_later and/or #import_with_lock:
        # log the unexpected event.
        Honeybadger.notify("Skipping import of no models to index #{self.class.name}")
        return
      end

      super
    end

    def import_with_lock(*models)
      return if includes_no_models_and_options?(models)

      model_class.transaction do
        # Chewy will always re-fetch the models, no advantage in loading them
        # here. Obtain locks in id order to avoid deadlock.
        model_class.lock("FOR SHARE OF #{model_class.table_name}").where(id: models.sort).order(:id).pluck(:id)

        # Pass through original `models` to allow Chewy to handle deletions
        import(*models)
      end
    end

    def import_later(*models)
      if models.last.is_a?(Hash)
        # We don't support passing Chewy import options through to the background job
        raise ArgumentError.new('Cannot import_later with a Chewy options hash')
      end

      return if includes_no_models_and_options?(models)

      connection = self.model_class.connection

      unless connection.transaction_open?
        AfterTransactionImporter.new(self, models).import!
        return
      end

      # To minimize holding references to models that might otherwise be
      # collectable, eagerly convert AR models with ids to the id. Models
      # without an id may yet gain one before the transaction is complete, so
      # must be retained as an object.
      models = models.map do |m|
        if m.is_a?(ActiveRecord::Base) && m.id
          m.id
        else
          m
        end
      end

      # We want to collect the imports for a given index to be enqueued for
      # import together at the end of the transaction, rather enqueuing each
      # invocation as a separate ActiveJob. This implementation won't be optimal
      # in the case of nested savepoint transactions, as each separate nested
      # transaction will have a separate job.
      transaction = connection.current_transaction
      if transaction_importers.key?(transaction)
        transaction_importers[transaction].add_models(models)
      else
        importer = AfterTransactionImporter.new(self, models)
        importer.add_to_transaction
        transaction_importers[transaction] = importer
      end
    end

    def transaction_importers
      @transaction_importers ||= ObjectSpace::WeakKeyMap.new
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

    # When an index can't be partitioned, but a single field can be in any
    # language, which is known at index time. We don't want to use a single
    # mapping with many `field` analysers, because analyzing and matching
    # against the value in the wrong language would be actively negative (e.g.
    # analyzing a Japanese string with a standard analyzer), so we use an object
    # with many fields keyed by language. We also want the raw string as a
    # keyword. When storing into an index, the string must be saved both as
    # `raw` and as the corresponding language.
    def arbitrary_language_string_mapping
      mapping = multi_language_mapping do |language|
        { type: 'text', analyzer: LANGUAGE_ANALYZERS.fetch(language, 'standard') }
      end

      mapping[:properties][:raw] = { type: 'keyword' }
      mapping
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
