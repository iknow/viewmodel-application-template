# frozen_string_literal: true

class TimePrecisionValidator < ActiveModel::EachValidator
  def precision
    options.fetch(:precision)
  end

  def validate_each(record, attr, value)
    return unless value.is_a?(Time)

    mask = 10**(9 - precision)
    unless (value.nsec % mask).zero?
      record.errors.add(attr, :time_precision, message: "may not exceed #{precision} places of sub-second precision")
    end
  end
end
