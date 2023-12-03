# frozen_string_literal: true

# A collection of parsed filters for a specific FilterSet, represented
# internally as { filter_name => value }
class FilterValues
  def initialize(filter_set)
    @filter_set = filter_set
    @filter_values = {}
  end

  def each_filter
    return to_enum(__method__) unless block_given?

    @filter_values.each do |filter_name, value|
      yield(@filter_set.fetch(filter_name), value)
    end
  end

  def can_scope?
    each_filter.all? do |filter, value|
      filter.can_scope?(value)
    end
  end

  def can_scope!
    raise IncompatibleParameters.new(filters: self, strategy: :scope) unless can_scope?
  end

  def can_search?
    each_filter.all? do |filter, value|
      filter.can_search?(value)
    end
  end

  def can_search!
    raise IncompatibleParameters.new(filters: self, strategy: :search) unless can_search?
  end

  # To be compatible with rails (>= 7), all conditions must be combined _on the
  # same scope_ with #and. We use the base table scope for consistency. In the
  # case of conditions that apply to a joined table, these joins are specified
  # separately via scope_joins_for, so that the joining scopes can be separately
  # #merge'd to the combined conditions.
  def scope
    condition_scopes = @filter_values.map do |filter_name, value|
      @filter_set[filter_name].scope_for(value, self)
    end

    # Merge conditions with #and to avoid clobbering range queries with Rails 7
    # semantics
    conditions = condition_scopes.inject do |a, b|
      a.and(b)
    end

    join_scopes = @filter_values.map do |filter_name, value|
      @filter_set[filter_name].scope_joins_for(value, self)
    end.compact

    join_scopes.inject(conditions) do |a, b|
      a.merge(b)
    end
  end

  def search_terms
    @filter_values.flat_map do |filter_name, value|
      @filter_set.fetch(filter_name).search_for(value)
    end
  end

  def []=(filter_name, filter_value)
    unless @filter_set.include?(filter_name)
      raise ArgumentError.new("Cannot add value for unknown filter '#{filter_name}'")
    end

    @filter_values[filter_name] = filter_value
  end

  delegate :[], :fetch, :delete, to: :@filter_values

  def include?(filter_name)
    @filter_values.has_key?(filter_name.to_sym)
  end

  def require!(*filter_names)
    missing = filter_names.reject { |filter_name| @filter_values.include?(filter_name.to_sym) }
    if missing.present?
      raise MissingFilterError.new(missing, all: true)
    end
  end

  def require_any!(*filter_names)
    unless filter_names.any? { |fn| @filter_values.include?(fn.to_sym) }
      raise MissingFilterError.new(filter_names, all: false)
    end
  end
end
