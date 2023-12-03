# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # Read a preloaded association without incurring the cost of constructing a CollectionProxy.
  def loaded_assoc(name)
    assoc = association(name)
    unless assoc.loaded?
      raise ArgumentError.new("Association #{self.class.name}:#{name} not loaded on id: #{self.id}")
    end

    assoc.target
  end

  # For a belongs_to association, true if either the association target or the
  # foreign key exists. Necessary because foreign key will be nil in the case
  # that the association is populated with an unsaved new record.
  def associated_to?(association_name)
    assoc = association(association_name)
    reflection = assoc.reflection

    unless reflection.macro == :belongs_to
      raise ArgumentError.new('May only be used for belongs_to associations')
    end

    if assoc.loaded?
      assoc.target.present?
    else
      attribute_present?(reflection.foreign_key)
    end
  end

  def self.default_type_for_column(column_name)
    connection.lookup_cast_type_from_column(columns_hash[column_name])
  end

  # This is used for formulating postgres ranges when dealing with where
  # clauses. If you need a literal, use connection.quote, which handles ranges
  # properly.
  #
  # If you try to use
  #
  #    where("time && ?", Time.now ... Time.now + 1.minute)
  #
  # you will get
  #
  #   `each': can't iterate from Time (TypeError)
  #
  # However, a literal sql expression, like a VALUES literal, or even
  # where("time && #{connection.quote(...)}") will work as expected. In the case
  # of the latter, please prefer bound parameters with this psql_range for
  # performance, since this will result in prepared statements.
  def self.psql_range(range)
    unbounded_begin = range.begin.nil? || (range.begin.is_a?(Numeric) && range.begin.infinite? == -1)
    unbounded_end   = range.end.nil? || (range.end.is_a?(Numeric) && range.end.infinite? == 1)

    exclude_begin = unbounded_begin
    exclude_end   = unbounded_end || range.exclude_end?

    range_begin = unbounded_begin ? nil : range.begin
    range_end   = unbounded_end ? nil : range.end
    psql_bounds = (exclude_begin ? '(' : '[') + (exclude_end ? ')' : ']')

    return range_begin, range_end, psql_bounds
  end

  def self.range_operator_scope(column_name, operator, table_name: self.table_name)
    column_name = PG::Connection.quote_ident(column_name.to_s)

    if table_name
      table_name = PG::Connection.quote_ident(table_name.to_s)
      column_name = "#{table_name}.#{column_name}"
    end

    condition = "#{column_name} #{operator} tsrange(?, ?, ?)"

    ->(range) { where(condition, *psql_range(range)) }
  end

  def self.range_intersection_scope(column_name, table_name: self.table_name)
    self.range_operator_scope(column_name, '&&', table_name:)
  end

  def self.range_contains_scope(column_name, table_name: self.table_name)
    self.range_operator_scope(column_name, '@>', table_name:)
  end

  module ActsAsEnumInspect
    def inspect
      "<#{self.class.name}:#{self.enum_constant}>"
    end
  end

  # Simplify initializing SQL-enum backed acts_as_enums using the block definition style.
  def self.acts_as_sql_enum(**args, &block)
    acts_as_enum(nil, sql_enum_type: model_name.singular, **args, &block)
  end

  def self.acts_as_enum(...)
    super
    ParamSerializers.register_enum_serializer(self)
    include ActsAsEnumInspect
  end

  # Adds reflection to belongs_to_enum synthetic attributes for use in schema generation
  EnumAttribute = Value.new(:name, :target_class, :foreign_key)

  def self.belongs_to_enum(enum_name, class_name: enum_name.to_s.camelize, foreign_key: "#{enum_name}_id")
    super
    @belongs_to_enum_attributes ||= {}
    @belongs_to_enum_attributes[enum_name.to_s] = EnumAttribute.with(name: enum_name.to_s, target_class: class_name.constantize, foreign_key:)
  end

  def self.belongs_to_enum_attribute(attribute_name)
    @belongs_to_enum_attributes.try { |a| a[attribute_name.to_s] }
  end

  # Order by an arbitrary expression: `order` will prepend `table_name.` to
  # the provided expression, producing bad SQL for anything that isn't a table
  # column.
  def self.order_by_expression(expression, direction = 'asc')
    order(Arel.sql("#{expression} #{direction.casecmp('desc').zero? ? 'DESC' : 'ASC'}"))
  end

  def self.reorder_by_expression(expression, direction = 'asc')
    reorder(Arel.sql("#{expression} #{direction.casecmp('desc').zero? ? 'DESC' : 'ASC'}"))
  end

  def self._build_values_select(entries:, name:, types:, projection:)
    table_name     = PG::Connection.quote_ident(name.to_s)
    column_names   = types.keys.map { |c| PG::Connection.quote_ident(c.to_s) }
    values_literal = quote_values_literal(entries, types.values, &projection)

    "(#{values_literal}) AS #{table_name}(#{column_names.join(', ')})"
  end

  VALUE_SELECT_BUILDER = KeywordBuilder.create(self, constructor: :_build_values_select)

  def self.build_values_select(entries, &)
    VALUE_SELECT_BUILDER.build!(entries:, &)
  end

  def self._build_values_table(entries:, name:, types:, projection:)
    table_name     = PG::Connection.quote_ident(name.to_s)
    column_names   = types.keys.map { |c| PG::Connection.quote_ident(c.to_s) }
    values_literal = quote_values_literal(entries, types.values, &projection)

    "#{table_name}(#{column_names.join(', ')}) AS (#{values_literal})"
  end

  VALUE_TABLE_BUILDER = KeywordBuilder.create(self, constructor: :_build_values_table)

  def self.build_values_table(entries, &)
    VALUE_TABLE_BUILDER.build!(entries:, &)
  end

  def self.quote_values_literal(entries, column_types)
    builder = +'VALUES '

    last_row     = entries.size - 1
    column_count = column_types.size
    last_column  = column_count - 1

    entries.each_with_index do |entry, row_idx|
      row = block_given? ? yield(entry) : entry

      raise ArgumentError.new unless row.size == column_count

      builder << '('
      row.each_with_index do |col, col_idx|
        builder << connection.quote(col)
        type = column_types[col_idx]
        builder << '::' << type if type
        builder << ', ' unless col_idx == last_column
      end
      builder << ')'
      builder << ', ' unless row_idx == last_row
    end

    builder.freeze
  end

  # Given the representation of a collection of enum members of an association
  # to a collection of models joining an acts_as_enum table on
  # `enum_member_key`, update the association to match the provided enum
  # `new_values`.
  def set_enum_collection(association_scope, enum_member_key, new_values)
    self.class.transaction do
      indexed_values = association_scope.index_by(&enum_member_key)
      current_values = indexed_values.keys

      added_values   = new_values     - current_values
      removed_values = current_values - new_values

      if added_values.present?
        # Allow assignment to a new record: schedule to be created.
        action = new_record? ? :build : :create!
        association_scope.public_send(action, added_values.map { |a| { enum_member_key => a } })
      end

      if removed_values.present?
        association_scope.destroy(indexed_values.fetch_values(*removed_values))
      end
    end
  end
end
