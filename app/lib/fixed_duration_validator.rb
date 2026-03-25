# frozen_string_literal: true

class FixedDurationValidator < SimpleDurationValidator
  def initialize(options = {})
    super(options.merge(allowed_part_groups: [:seconds]))
  end
end
