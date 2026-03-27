# frozen_string_literal: true

# Each filter specifies a IknowParams serializer for an input value, at least
# one of:
# `scope`: An ActiveRecord scope to enforce the filter. Specified as a block
#          taking the input value and returning the scope
# `search`: One or more ElasticSearch filter-context queries to enforce the
#           filter. Specified as a block taking the input value and returning
#           the query/ies.
# Options:
# `default`:  A default value for the filter. May be determined at request time
#             by specifying a block taking the current_filters.
# `required`: true if a value for the filter must be provided, may be
#             determined at request time by specifying a block taking the
#             current_filters.
# `only`:     Array of controller actions that the filter is limited to.
# `except`:   Array of controller actions that the filter is excluded from.
no_default = Object.new
Filter = Value.new(:name,
                   format:        ParamSerializers::String,
                   scope:         nil,
                   scope_joins:   nil,
                   search:        nil,
                   default:       no_default,
                   only:          [],
                   except:        [],
                   aliases:       [],
                   required:      false,
                   permit_scope:  nil,
                   permit_search: nil,
                  ) do
  self::NO_DEFAULT = no_default

  @builder = KeywordBuilder.create(self, constructor: :with)
  singleton_class.delegate :build!, to: :@builder

  def initialize(name, format, scope, scope_joins, search, default, only, except, aliases, required, permit_scope, permit_search)
    unless scope || search
      raise ArgumentError.new('Filters must specify at least one of an ActiveRecord scope'\
                              'or an ElasticSearch filter term')
    end
    if only.present? && except.present?
      raise ArgumentError.new('Filters may specify only one of `only` and `except`')
    end

    super
  end

  def can_scope?(value)
    return false unless scope.present?

    permit_scope.nil? || permit_scope.call(value)
  end

  def scope_for(value, filters, controller: self)
    controller.instance_exec(value, filters, &scope)
  end

  def scope_joins_for(value, filters, controller: nil)
    return nil unless scope_joins

    controller.instance_exec(value, filters, &scope_joins)
  end

  def can_search?(value)
    return false unless search.present?

    permit_search.nil? || permit_search.call(value)
  end

  def search_for(value, filters, controller: nil)
    controller.instance_exec(value, filters, &search)
  end

  def valid_for_action?(action_name)
    if only.present?
      only.include?(action_name)
    elsif except.present?
      !except.include?(action_name)
    else
      true
    end
  end

  def default?
    default != Filter::NO_DEFAULT
  end

  def default_value(filters)
    if default.is_a?(Proc)
      default.call(filters)
    else
      default
    end
  end

  def required?(filters)
    if required.is_a?(Proc)
      required.call(filters)
    else
      required
    end
  end

  def names
    return to_enum(__method__) unless block_given?

    yield name
    aliases.each { |a| yield(a) }
  end
end
