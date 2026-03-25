# frozen_string_literal: true

class SimpleDurationValidator < ActiveModel::EachValidator
  KNOWN_PART_GROUPS = {
    months:  [:years, :months],
    days:    [:weeks, :days],
    seconds: [:hours, :minutes, :seconds],
  }.freeze

  DEFAULT_PART_GROUPS = [
    :months, :days, :seconds,
  ].freeze

  def validate_each(record, attribute, value)
    # Handles errant values as well as nils. If a nil is to be allowed, use the rails `allow_nil: true` option.
    unless value.is_a?(ActiveSupport::Duration)
      record.errors.add(
        attribute,
        :not_a_duration,
        message: 'must be a duration')
      return
    end

    allowed_parts = options.fetch(:allowed_part_groups) { DEFAULT_PART_GROUPS }

    result = SimpleDurationValidator.check_parts(value, allowed_parts:)

    if result == :complex_duration
      record.errors.add(
        attribute,
        :complex_duration,
        message: 'may not include a mixture of months, days, and seconds')
    end

    if result == :invalid_parts
      record.errors.add(
        attribute,
        :invalid_parts,
        message: "may only include parts compatible with #{allowed_parts.join(',')}")
    end
  end

  def self.check_parts(duration, allowed_parts: DEFAULT_PART_GROUPS)
    part_types = duration.parts.keys

    # check if duration is complex (composed of multiple part groups)
    num_groups = KNOWN_PART_GROUPS.values.count do |group|
      part_types.intersect?(group)
    end

    return :complex_duration if num_groups > 1

    # zero-durations are serialized as PT0S so skip the part checking
    return nil if duration.to_i == 0

    # check that all parts belong to allowed groups
    allowed_part_types = allowed_parts.flat_map { |part| KNOWN_PART_GROUPS.fetch(part) }
    return :invalid_parts if (part_types - allowed_part_types).present?

    return nil
  end

  def self.simple_duration?(...)
    check_parts(...).nil?
  end
end
