# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SimpleDurationValidator do
  describe 'check_parts' do
    it 'works' do
      expect(SimpleDurationValidator.check_parts(1.day)).to eq(nil)
    end

    it 'disallows complex durations' do
      expect(SimpleDurationValidator.check_parts(1.day + 1.hour)).to eq(:complex_duration)
    end

    it 'validates part groups' do
      expect(SimpleDurationValidator.check_parts(1.day, allowed_parts: [:seconds])).to eq(:invalid_parts)
    end

    it 'disallows complex durations with part groups' do
      expect(SimpleDurationValidator.check_parts(1.day + 1.hour, allowed_parts: [:seconds])).to eq(:complex_duration)
    end
  end
end
