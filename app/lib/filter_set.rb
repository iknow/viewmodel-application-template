# frozen_string_literal: true

class FilterSet
  def initialize
    @filters = {}
  end

  def add_filter(name, **args, &block)
    raise ArgumentError.new("Filter #{name} already defined") if @filters.has_key?(name)

    filter = Filter.build!(name:, **args, &block)
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
