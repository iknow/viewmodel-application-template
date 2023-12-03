# frozen_string_literal: true

##
# Provides paginated search functionality for controllers using
# ApplicationSearch subclasses.
module Searching
  extend ActiveSupport::Concern

  class_methods do
    def search_with(search_class)
      unless search_class.is_a?(Class) && search_class < ApplicationSearch
        raise ArgumentError.new('Search class must be an ApplicationSearch')
      end

      searchable!
      @default_search_class = search_class
    end

    def default_search_class
      unless searchable?
        raise RuntimeError.new("Search class is not defined for #{self.name}. "\
                               'Set using `search_with` before performing search.')
      end

      @default_search_class
    end

    def searchable!
      @searchable = true
    end

    def searchable?
      @searchable
    end
  end

  def perform_search(query_string, filters: nil, page: nil, translation_language: nil,
                     with: self.class.search_class, lock: nil, filter_only: false)
    with.model_class.transaction do
      search = with.new(query_string, filters:, page:, filter_only:, translation_language:)

      models    = search.load_models(lock:)
      model_ids = models.each_with_object(Set.new) { |m, s| s << m.id }

      # We may not have been able to resolve models for each of the ES results:
      # filter stale entities from total counts and supplementary data
      stale_count = search.size - models.size
      add_response_metadata(:search, SearchResultView.new(search.total - stale_count, stale_count))

      if page
        last_page = !page.size_limit? || (page.start + page.page_size) >= search.total
        add_response_metadata(:pagination, PaginationView.new(page, last_page:))
      end

      search.supplementary_data.each do |field_name, data|
        data.filter! { |id, _| model_ids.include?(id) }

        add_supplementary_data(field_name, data)
      end

      models
    end

  rescue Elasticsearch::Transport::Transport::Errors::BadRequest => ex
    # TODO: ElasticSearch errors are highly structured, but String-encoded by
    # the Ruby wrapper. Parse the exception details and raise a better error.
    raise ViewModel::Error.new(detail: ex.message, code: 'Search.BadRequest', status: 502)
  end

  class SearchResultView < ViewModel
    attributes :total_count
    attributes :stale_results
  end
end
