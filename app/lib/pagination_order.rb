# frozen_string_literal: true

# Controllers can define many named pagination orders. Each PaginationOrder
# has a `name` and a `default_direction`, and may describe
# `scope`:  An ActiveRecord scope to enforce the order. Specified as a block
#           taking a direction and optionally a set of filter values and
#           returning the scope.
#           Defaults to ordering by the attribute matching `name`.
# `search`: An ElasticSearch `sort` specifier. Specified as a block taking
#           a direction and returning the sort. Defaults to ordering by the
#           field matching `name`
PaginationOrder = Value.new(:name, :default_direction, :scope, :search, aliases: []) do
  @builder = KeywordBuilder.create(self, constructor: :with)
  singleton_class.delegate :build!, to: :@builder

  def can_scope?
    scope.present?
  end

  def can_scope!
    raise IncompatibleParameters.new(filters: [], page: self, strategy: :scope) unless can_scope?
  end

  def can_search?
    search.present?
  end

  def can_search!
    raise IncompatibleParameters.new(filters: [], page: self, strategy: :search) unless can_search?
  end

  def scope_for(direction, filter_values)
    scope.call(direction, filter_values)
  end

  def search_for(direction)
    search.call(direction)
  end

  def names
    return to_enum(__method__) unless block_given?

    yield name
    aliases.each { |a| yield(a) }
  end
end
