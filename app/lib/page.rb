# frozen_string_literal: true

# A parsed pagination result, specifying a given order and window
Page = Value.new(:name, :order, :direction, :start, :page_size, :compute_total_count) do
  # Apply this Page's ordering to the scope
  def ordering_scope(filter_values, controller: nil)
    order.scope_for(direction, filter_values, controller:)
  end

  # Limit the scope to this Page and compute totals. Wraps the scope rather than
  # returning a scope to be merged because a subquery may be necessary for counting.
  def pagination_scope(scope)
    if compute_total_count?
      # Nest the original scope into a subquery and add a window function to count total results
      query_sql = scope.to_sql
      model = scope.klass
      scope = model.from("(#{query_sql}) pagination_nested_scope")
                .select('pagination_nested_scope.*', 'count(*) OVER () AS pagination_total_count')
    end

    scope = scope.offset(start) if start > 0
    # Request one more record than the page size so we can determine whether
    # we're the last page even if we don't have the total count.
    scope = scope.limit(page_size + 1) if size_limit?
    scope
  end

  def compute_total_count?
    compute_total_count
  end

  def size_limit?
    page_size > 0
  end

  delegate :can_scope?, :can_scope!, :can_search?, :can_search!, to: :order
end
