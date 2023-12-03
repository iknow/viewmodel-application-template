# frozen_string_literal: true

# A parsed pagination result, specifying a given order and window
Page = Value.new(:name, :order, :direction, :start, :page_size) do
  def scope(filter_values)
    scope = order.scope_for(direction, filter_values)
    scope = scope.offset(start) if start > 0
    # Request one more record than the page size so we can determine whether we're the last page.
    scope = scope.limit(page_size + 1) if size_limit?
    scope
  end

  def size_limit?
    page_size > 0
  end

  delegate :can_scope?, :can_scope!, :can_search?, :can_search!, to: :order
end
