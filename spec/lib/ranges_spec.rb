# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ranges do
  describe 'range_before?' do
    it 'works' do
      expect(subject.range_before?(1..2, 2..3)).to eq(false)
      expect(subject.range_before?(1...2, 2..3)).to eq(true)

      expect(subject.range_before?(1..2, 3..4)).to eq(true)
      expect(subject.range_before?(3..4, 1..2)).to eq(false)
    end

    it 'handles unbounded ranges' do
      expect(subject.range_before?(nil...1, 1..nil)).to eq(true)
      expect(subject.range_before?(nil...1, 1..nil)).to eq(true)

      expect(subject.range_before?(nil...nil, 1..nil)).to eq(false)
      expect(subject.range_before?(nil...nil, nil..nil)).to eq(false)
    end
  end

  describe 'ranges_overlap?' do
    it 'works' do
      expect(subject.ranges_overlap?(1..2, 2..3)).to eq(true)
      expect(subject.ranges_overlap?(1..2, 2...3)).to eq(true)
      expect(subject.ranges_overlap?(1...2, 2...3)).to eq(false)

      expect(subject.ranges_overlap?(1..5, 3...10)).to eq(true)
      expect(subject.ranges_overlap?(1..5, 10..11)).to eq(false)
    end
  end

  describe 'intersect_ranges' do
    it 'handles regular ranges' do
      expect(subject.intersect_ranges(1..2, 2..3)).to eq(2..2)
      expect(subject.intersect_ranges(1..5, 3..10)).to eq(3..5)
    end

    it 'rejects impossible ranges' do
      expect { subject.intersect_ranges(1..2, 3..4) }.to raise_error(ArgumentError)
      expect { subject.intersect_ranges(1...2, 2..3) }.to raise_error(ArgumentError)
    end

    it 'unifies differing exclude_end' do
      expect(subject.intersect_ranges(1...4, 3..4)).to eq(3..3)
      expect(subject.intersect_ranges(1...4.0, 3..4)).to eq(3...4.0)

      expect(subject.intersect_ranges(1..4, 3...4)).to eq(3..3)
      expect(subject.intersect_ranges(1..4, 3...4.0)).to eq(3...4.0)
    end

    it 'handles unbounded ranges' do
      expect(subject.intersect_ranges(nil..2, 2..3)).to eq(2..2)
      expect(subject.intersect_ranges(1..nil, 2..3)).to eq(2..3)
      expect(subject.intersect_ranges(1..2, nil..3)).to eq(1..2)
      expect(subject.intersect_ranges(1..2, 2..nil)).to eq(2..2)
      expect(subject.intersect_ranges(nil..2, 2..nil)).to eq(2..2)
      expect(subject.intersect_ranges(2..nil, nil..2)).to eq(2..2)
    end
  end
end
