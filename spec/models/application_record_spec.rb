# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationRecord do
  subject { ApplicationRecord }

  describe 'psql_range' do
    let(:now) { utc_now }
    let(:soon) { utc_now.advance(minutes: 5) }
    it 'does the right thing' do
      [
        # Basics
        [(1..2), [1, 2, '[]']],
        [(1...2), [1, 2, '[)']],
        [(1..), [1, nil, '[)']],
        [(1...), [1, nil, '[)']],
        [(..2), [nil, 2, '(]']],
        [(...2), [nil, 2, '()']],

        # Alternate ways of expressing unbounded begins and ends
        [(-Float::INFINITY..1), [nil, 1, '(]']],
        [(1..Float::INFINITY), [1, nil, '[)']],
        [(1...Float::INFINITY), [1, nil, '[)']],

        # Times
        [(now..), [now, nil, '[)']],
        [(now...), [now, nil, '[)']],
        [(..now), [nil, now, '(]']],
        [(...now), [nil, now, '()']],
        [(now..soon), [now, soon, '[]']],
        [(now...soon), [now, soon, '[)']],
      ].each do |range, expected|
        expect(subject.psql_range(range)).to eq(expected), range.inspect
      end
    end
  end
end
