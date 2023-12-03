# frozen_string_literal: true

module ChewyIndexHelper
  extend ActiveSupport::Concern

  # RSpec has a helper that corrupts hashes passed to functions that also take
  # keywords. Here we extend our definition to accept extra
  # initial_search_indexes as keyword arguments and merge them to undo the
  # damage.
  #
  # See https://github.com/rspec/rspec-support/commit/8c3a1bb9e198a816136c3dd891eebcbc600bc825#diff-f58e20f4536361cf86ea5f64662fb34eb9ef650ecc96d443bca0e8310dce84ab
  RSpec.shared_examples 'with search indexes' do |initial_search_indexes = {}, wrap_examples: true, **rspec_helper_indexes|
    include ActiveJob::TestHelper

    let(:search_indexes) { initial_search_indexes.merge(rspec_helper_indexes) }
    let(:unique_indexes) { search_indexes.values.tap(&:flatten!).tap(&:uniq!) }

    let(:indexed_languages) { [Language::EN, Language::JA] }

    def reset_indexes!
      unique_indexes.each do |index|
        if index < LanguagePartitionedIndex
          index.reset_languages!(indexed_languages)
        else
          index.reset!
        end
      end
    end

    def purge_indexes!
      unique_indexes.each do |index|
        if index < LanguagePartitionedIndex
          index.purge_languages!(indexed_languages)
        else
          index.purge!
        end
      end
    end

    def clear_index(index)
      index.create! unless index.exists?
      index.query({ match_all: {} }).delete_all
    end

    def clear_indexes!
      unique_indexes.each do |index|
        if index < LanguagePartitionedIndex
          indexed_languages.each do |lang|
            clear_index(index[lang])
          end
        else
          clear_index(index)
        end
      end
    end

    # Force immediate execution of the background index update job
    around(:each) do |example|
      perform_enqueued_jobs do
        example.call
      end
    end

    if wrap_examples
      around(:each) do |example|
        clear_indexes!
        Chewy.strategy(:urgent)
        example.call
        Chewy.strategy.pop
      end
    end

    def create(type, *)
      super.tap do |model|
        _import_to_index(type, model)
      end
    end

    def create_list(type, *)
      super.tap do |models|
        _import_to_index(type, models)
      end
    end

    def index!(model)
      type = model.class.name.underscore.to_sym
      _import_to_index(type, model)
    end

    private

    def _import_to_index(type, models)
      indexes = Array.wrap(search_indexes[type])
      return unless indexes.present?

      models  = Array.wrap(models)

      indexes.each do |index|
        if index < LanguagePartitionedIndex
          language = models.first.language
          expect(indexed_languages).to include(language)
          index[language].import(models)
        else
          index.import(models)
        end
      end
    end
  end
end
