# frozen_string_literal: true

# Adds support for defining filters for viewmodel controllers.
module Filtering
  extend ActiveSupport::Concern

  class_methods do
    def available_filters
      @available_filters ||= FilterSet.new
    end

    def request_filter(name, ...)
      available_filters.add_filter(name, ...)
    end

    def inherited(controller)
      super

      # Always permit filtering by id: this provides an equivalent of a bulk GET
      controller.request_filter(:id) do
        aliases [:ids]
        format IknowParams::Serializer::ArrayOf.new(IknowParams::Serializer::UUID, allow_singleton: true)

        scope { |ids| controller.model_class.where(id: ids) }

        search do |ids|
          {
            bool: {
              should: ids.map { |id| { term: { 'id' => id } } },
            },
          }
        end
      end
    end
  end

  def current_filters
    @current_filters ||= parse_filters
  end

  private

  # Parses filters specified in params
  def parse_filters
    available_filters = self.class.available_filters

    action_filters = available_filters.each_filter.select do |filter|
      filter.valid_for_action?(self.action_name.to_sym)
    end

    # Parse params
    parsed_filter_values = available_filters.new_filter_values

    action_filters.each do |filter|
      matched_param_name = filter.names.detect { |name| params.has_key?(name) }

      if matched_param_name
        parsed_filter_values[filter.name] = parse_param(matched_param_name, with: filter.format)
      end
    end

    # Apply defaults
    action_filters.each do |filter|
      if !parsed_filter_values.include?(filter.name) && filter.default?
        parsed_filter_values[filter.name] = filter.default_value(parsed_filter_values)
      end
    end

    # Detect missing filters
    missing = action_filters.select do |filter|
      !parsed_filter_values.include?(filter.name) && filter.required?(parsed_filter_values)
    end

    if missing.present?
      raise MissingFilterError.new(*missing.map(&:name), all: true)
    end

    parsed_filter_values
  end
end
