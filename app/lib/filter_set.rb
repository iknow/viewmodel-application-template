# frozen_string_literal: true

class FilterSet
  class OverlappingFilterNames < StandardError
    attr_reader :filter, :filter_name, :existing_filter, :existing_filter_name

    def initialize(filter:, filter_name:, existing_filter:, existing_filter_name:)
      super()

      @filter = filter
      @filter_name = filter_name
      @existing_filter = existing_filter
      @existing_filter_name = existing_filter_name
    end

    def message
      "Request filter #{describe_name(filter, filter_name)} collides with existing filter #{describe_name(existing_filter, existing_filter_name)}"
    end

    private

    def describe_name(filter, filter_name)
      if filter.name == filter_name
        "'#{filter.name}'"
      else
        "'#{filter_name}' (alias of '#{filter.name}')"
      end
    end
  end

  def initialize
    @filters = {}
  end

  def add_filter(name, **args, &block)
    raise ArgumentError.new("Filter #{name} already defined") if @filters.has_key?(name)

    filter = Filter.build!(name:, **args, &block)

    unless Rails.env.production?
      filter.names.each do |filter_name|
        each_filter.each do |existing_filter|
          existing_filter.names.each do |existing_filter_name|
            if filter_name == existing_filter_name
              raise OverlappingFilterNames.new(filter:, filter_name:, existing_filter:, existing_filter_name:)
            end
          end
        end
      end
    end

    @filters[name] = filter
  end

  def new_filter_values
    FilterValues.new(self)
  end

  def each_filter
    return to_enum(__method__) unless block_given?

    @filters.each_value { |x| yield(x) }
  end

  def include?(filter_name)
    @filters.has_key?(filter_name)
  end

  delegate :[], :fetch, to: :@filters
end
