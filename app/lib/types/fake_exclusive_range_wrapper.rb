# frozen_string_literal: true

# We incorrectly used end-inclusive time ranges in the database for a long time,
# which causes issues as soon as we want to have adjacent but unique ranges.
# We've switched to using end-exclusive ranges, but there's a lot of data in the
# database to gradually migrate. In order to handle this during the backfill,
# when loading existing end-inclusive ranges from the database, transform them
# to end-exclusive.
class Types::FakeExclusiveRangeWrapper < ActiveRecord::Type::Value
  attr_reader :subtype

  def initialize(subtype = nil)
    super()
    @subtype = subtype
  end

  def serialize(value)
    subtype.serialize(value)
  end

  def deserialize(value)
    range = subtype.deserialize(value)

    if range && !range.exclude_end?
      Range.new(range.begin, range.end, true)
    else
      range
    end
  end
end
