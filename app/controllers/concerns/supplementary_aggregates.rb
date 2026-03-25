# frozen_string_literal: true

module SupplementaryAggregates
  extend ActiveSupport::Concern

  included do
    backgroundable_action :show
  end

  class_methods do
    def add_supplementary_aggregates(*aggregate_classes)
      (@supplementary_aggregates ||= []).concat(aggregate_classes)
    end

    def supplementary_aggregates
      raise RuntimeError.new('no aggregates configured') unless @supplementary_aggregates.present?

      @supplementary_aggregates
    end
  end

  class AggregatePageSizeTooLarge < ServiceError
    status 400
    code 'SupplementaryAggregate.PageSizeTooLarge'
    detail 'The page size you requested was too large for a foregrounded request with a supplementary aggregate range. Please rerequest asynchronously.'

    def initialize(max_page_size)
      super()
      @max_page_size = max_page_size
    end

    def meta
      { max_page_size: @max_page_size }
    end
  end

  def show(...)
    validate_aggregate_size!
    super do |view|
      view = yield(view) if block_given?
      add_supplementary_aggregates([view])
      view
    end
  end

  def index(...)
    validate_aggregate_size!
    super do |views|
      views = yield(views) if block_given?
      add_supplementary_aggregates(views)
      views
    end
  end

  def search(...)
    validate_aggregate_size!
    super do |views|
      views = yield(views) if block_given?
      add_supplementary_aggregates(views)
      views
    end
  end

  def aggregate_range
    @aggregate_range ||= parse_param(:aggregate_range, with: ParamSerializers::ExclusiveTimeRange)
  end

  def maximum_foreground_aggregate_page_size
    50
  end

  def validate_aggregate_size!
    return unless include_any_supplementary_aggregates?
    return if is_a?(BackgroundRendering) && backgrounded?

    if !current_page.size_limit? || current_page.page_size > maximum_foreground_aggregate_page_size
      raise AggregatePageSizeTooLarge.new(maximum_foreground_aggregate_page_size)
    end
  end

  def add_supplementary_aggregates(views)
    self.class.supplementary_aggregates.each do |aggregate|
      next unless include_supplementary_aggregate?(aggregate)

      view_ids = views.map(&:id)
      viewmodel_class = aggregate.viewmodel_class
      range = self.aggregate_range if aggregate.requires_range?
      scope, key = aggregate.scope_for(self.model_class)
      scope = scope.where(key => view_ids)

      aggregates = aggregate.calculate_aggregates(key, scope, range)

      # Add empty aggregate for any missing
      empty_aggregate = aggregate.empty
      view_ids.each do |id|
        aggregates[id] ||= empty_aggregate
      end

      aggregate_views = aggregates.transform_values { |model| viewmodel_class.new(model) }
      add_supplementary_data(aggregate.aggregate_name, aggregate_views)
    end
  end

  def include_any_supplementary_aggregates?
    self.class.supplementary_aggregates.any? do |aggregate|
      include_supplementary_aggregate?(aggregate)
    end
  end

  def include_supplementary_aggregate?(aggregate)
    name = aggregate.aggregate_name
    parse_boolean_param("include_#{name}", default: false)
  end
end
