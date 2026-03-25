# frozen_string_literal: true

class OffsetsValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.nil?
      record.errors.add(attribute, :null, message: 'must not be null')
      return
    end

    unless value.is_a?(Array)
      record.errors.add(attribute, :invalid_offsets, message: 'must be an array')
      return
    end

    unless value.present? || options[:required] == false
      record.errors.add(attribute, :empty_offsets, message: 'must be non-empty')
      return
    end

    valid_pairs = value.all? do |off, len, *rest|
      rest.blank? && off.integer? && len.integer? && !off.negative? && len.positive?
    end

    unless valid_pairs
      record.errors.add(attribute, :invalid_offsets, message: 'must only include [offset, length] pairs')
    end

    last_offset = -1
    last_length = 0

    value.each do |offset, length|
      if offset < last_offset
        record.errors.add(attribute, :out_of_order_offsets,
                          message: "are out of order: (#{last_offset},#{last_length}), (#{offset},#{length})")
      elsif offset < (last_offset + last_length)
        record.errors.add(attribute, :overlapping_offsets,
                          message: "are overlapping: (#{last_offset},#{last_length}), (#{offset},#{length})")
      end

      last_offset = offset
      last_length = length
    end
  end
end
