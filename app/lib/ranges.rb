# frozen_string_literal: true

module Ranges
  class UnlikeRanges < ArgumentError; end
  class NonOverlapping < ArgumentError; end

  class << self
    # true if x is strictly before y
    def range_before?(x, y)
      return false if x.end.nil? || y.begin.nil?

      if x.exclude_end?
        x.end <= y.begin
      else
        x.end < y.begin
      end
    end

    # true if there are any common values in two ranges
    def ranges_overlap?(x, y)
      # Ranges overlap unless one is strictly before or after the other
      !(range_before?(x, y) || range_before?(y, x))
    end

    # Return a new range that covers all values covered by either input range.
    # Raises if the result would need to contain two disjoint sub-ranges.
    def union_ranges(x, y)
      x, y = normalize_inclusivity(x, y)

      # Ranges must either overlap or abut
      unless ranges_overlap?(x, y) || x.end == y.begin || y.end == x.begin
        raise NonOverlapping.new('Cannot union non-overlapping ranges')
      end

      min =
        case
        when x.begin.nil?;      nil
        when y.begin.nil?;      nil
        when x.begin < y.begin; x.begin
        else                    y.begin
        end

      max =
        case
        when x.end.nil?;    nil
        when y.end.nil?;    nil
        when x.end > y.end; x.end
        else                y.end
        end

      Range.new(min, max, x.exclude_end?)
    end

    # Return a new range, such that all values covered by the new range are
    # covered by both input ranges.  Raises if there are no values.
    def intersect_ranges(x, y)
      x, y = normalize_inclusivity(x, y)

      unless ranges_overlap?(x, y)
        raise NonOverlapping.new('Cannot intersect non-overlapping ranges')
      end

      min =
        case
        when x.begin.nil?;      y.begin
        when y.begin.nil?;      x.begin
        when x.begin > y.begin; x.begin
        else y.begin
        end

      max =
        case
        when x.end.nil?;    y.end
        when y.end.nil?;    x.end
        when x.end < y.end; x.end
        else y.end
        end

      Range.new(min, max, x.exclude_end?)
    end

    def normalize_inclusivity(x, y)
      # Can only normalize if we can unify the exclude_end properties
      if x.exclude_end? != y.exclude_end?
        case
        when x.exclude_end? && x.end.is_a?(Integer)
          x = (x.begin) .. (x.end - 1)
        when y.exclude_end? && y.end.is_a?(Integer)
          y = (y.begin) .. (y.end - 1)
        when !x.exclude_end? && x.end.is_a?(Integer)
          x = (x.begin) ... (x.end + 1)
        when !y.exclude_end? && y.end.is_a?(Integer)
          y = (y.begin) ... (y.end + 1)
        else
          raise UnlikeRanges.new('Cannot normalize unlike ranges')
        end
      end

      return [x, y]
    end

    def range_empty?(r)
      r.exclude_end? && r.begin && r.end && r.begin == r.end
    end
  end
end
