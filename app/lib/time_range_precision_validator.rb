# frozen_string_literal: true

class TimeRangePrecisionValidator < ActiveModel::EachValidator
  def precision
    options.fetch(:precision)
  end

  def validate_each(record, attr, value)
    return unless value.is_a?(Range)

    validate_time(record, attr, :begin, value.begin)
    validate_time(record, attr, :end, value.end)
  end

  private

  def validate_time(record, attr, part, time)
    return unless time.is_a?(Time)

    mask = 10**(9 - precision)
    unless (time.nsec % mask).zero?
      record.errors.add(attr, :time_range_precision, message: "#{part} may not exceed #{precision} places of sub-second precision")
    end
  end
end
