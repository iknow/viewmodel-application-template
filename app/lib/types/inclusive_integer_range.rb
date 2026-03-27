# frozen_string_literal: true

# Non-infinite Integer ranges can always be expressed as either inclusive or
# exclusive. PostgreSQL prefers to normalize them as start-inclusive and
# end-exclusive, whereas we prefer both inclusive. Wrap the PostgreSQL::OID::Range
# value serializer to convert end-exclusive ranges to inclusive ones.
class Types::InclusiveIntegerRange < Types::NilBoundedRange
  def deserialize(value)
    range = super(value)

    if range && range.exclude_end? && !range.end.infinite?
      Range.new(range.min, range.max)
    else
      range
    end
  end
end
