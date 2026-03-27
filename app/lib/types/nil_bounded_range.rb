# frozen_string_literal: true

# PostgreSQL::OID::Range constructs unbounded ranges with postive and negative
# `Float::INFINITY` values as bound values, rather than using Ruby's native
# unbounded ranges which use `nil` instead. This falls flat with date ranges, as
# `Range.new(-Float::INFINITY, Time.now)` is invalid, unlike `Range.new(nil,
# Time.now)`. Override PostgreSQL::OID::Range's infinity handling to use nil
# values instead.
class Types::NilBoundedRange < ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Range
  attr_reader :connection

  def self.from_inferred_type(inferred_type, connection:)
    return inferred_type unless inferred_type.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Range)

    self.new(inferred_type, connection:)
  end

  def initialize(inferred_type, connection:)
    super(inferred_type.subtype, inferred_type.type)
    @connection = connection
  end

  def infinity(negative: false)
    nil
  end

  def infinity?(value)
    # continue to handle Float::Infinity values for serializing ranges back to
    # the database
    value.nil? || super
  end

  # Rails 8.1 broke things even worse.
  def serialize(value)
    range = super(value)
    if range.is_a?(::Range)
      lower_bound = infinity?(range.begin) ? '' : connection.type_cast(range.begin)
      upper_bound = infinity?(range.end) ? '' : connection.type_cast(range.end)
      "[#{lower_bound},#{upper_bound}#{range.exclude_end? ? ')' : ']'}"
    else
      range
    end
  end
end
