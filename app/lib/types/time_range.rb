# frozen_string_literal: true

class Types::TimeRange < Types::NilBoundedRange
  SURROGATE_EMPTY_RANGE = Time.parse('2000-01-01T00:00:00Z').then { |t| t ... t }
  def cast_value(value)
    if value == 'empty'
      # PostgreSQL::OID::Range handles empty values by returning nil, which
      # prevents us from round-tripping a NOT NULL column, or using range
      # operations in Ruby. Instead, deserialize the empty value as an arbitrary
      # empty end-exclusive range.
      SURROGATE_EMPTY_RANGE
    else
      super
    end
  end
end
