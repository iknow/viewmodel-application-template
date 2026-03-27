# frozen_string_literal: true

# We can't use native ES time ranges yet, so to represent unbounded ranges we
# use proxy values.
module SearchRangeFormatting
  extend ActiveSupport::Concern

  OLDEST = Time.parse('-9999-01-01 00:00:00 UTC').iso8601.freeze
  NEWEST = Time.parse('9999-12-31 23:59:59 UTC').iso8601.freeze

  def format_range_for_search(json, range)
    beginless = range.begin.nil? || range.begin == -Float::INFINITY
    endless   = range.end.nil?   || range.end == Float::INFINITY

    json.gte beginless ? OLDEST : range.begin.iso8601
    json.lte endless   ? NEWEST : range.end.iso8601
  end
end
