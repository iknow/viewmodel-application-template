# frozen_string_literal: true

module SearchHelper
  extend ActiveSupport::Concern
  extend RSpec::Matchers::DSL

  included do
    before(:context) do
      Chewy.strategy(:urgent)
    end

    after(:context) do
      Chewy.strategy.pop
    end
  end

  def query
    '*'
  end

  def filter_values
    {}
  end

  def filters
    FilterValues.new(filtering_controller.available_filters).tap do |f|
      filter_values.each { |name, val| f[name] = val }
    end
  end

  def page
    nil
  end

  def new_page(order:, direction:, start:, page_size:, compute_total_count:)
    Page.new(
      order,
      filtering_controller.pagination_config.pagination_order(order),
      direction,
      start,
      page_size,
      compute_total_count)
  end

  def search_results
    @search_results ||= perform_search
  end

  # If the search filters rely on being evaluated in the context of an actual
  # controller action, extend this mock to provide the required interface.
  def mock_controller_for_search
    instance_double(filtering_controller)
  end

  def perform_search_raw(query = self.query, **extra_filters)
    filters = self.filters
    extra_filters.each { |name, value| filters[name] = value }
    described_class.new(query, filters:, page:, controller: mock_controller_for_search)
  end

  def perform_search(query = self.query, **extra_filters)
    perform_search_raw(query, **extra_filters).load_models
  end

  def clear_index(index)
    index.create! unless index.exists?
    index.query({ match_all: {} }).delete_all
  end
end
