# frozen_string_literal: true

class RangeFormatValidator < ActiveModel::EachValidator
  def end_exclusive?
    options.fetch(:exclude_end, nil)
  end

  def beginless?
    options.fetch(:beginless, nil)
  end

  def endless?
    options.fetch(:endless, nil)
  end

  def reverse?
    options.fetch(:reverse, false)
  end

  def allow_empty?
    options.fetch(:allow_empty, true)
  end

  def validate_each(record, attribute, value)
    unless value.is_a?(Range)
      record.errors.add(attribute, :range_format, message: 'must be a range')
      return
    end

    unless end_exclusive?.nil? || end_exclusive? == (value.exclude_end? || value.end.nil?)
      requirement = end_exclusive? ? 'must' : 'must not'
      record.errors.add(attribute, :range_end_exclusivity, message: "#{requirement} be an end-exclusive range", required: end_exclusive?)
    end

    unless allow_empty? || !Ranges.range_empty?(value)
      record.errors.add(attribute, :range_empty, message: 'must not be an empty range')
    end

    unless beginless?.nil? || beginless? == (value.begin.nil? || value.begin == -Float::INFINITY)
      requirement = beginless? ? 'must' : 'must not'
      required_bound = beginless? ? 'infinite' : 'finite'
      record.errors.add(attribute, :range_bound, message: "#{requirement} be a beginless range", bound: :lower, required_bound:)
    end

    unless endless?.nil? || endless? == (value.end.nil? || value.end == Float::INFINITY)
      requirement = endless? ? 'must' : 'must not'
      required_bound = endless? ? 'infinite' : 'finite'
      record.errors.add(attribute, :range_bound, message: "#{requirement} be an endless range", bound: :upper, required_bound:)
    end

    unless reverse?.nil? || value.end.nil? || value.begin.nil?
      if (reverse? && value.end > value.begin) || (!reverse? && value.end < value.begin)
        requirement = reverse? ? 'must' : 'must not'
        record.errors.add(attribute, :range_end_reverse, message: "#{requirement} be a reverse range", required: reverse?)
      end
    end
  end
end
