# frozen_string_literal: true

require 'rails_helper'
require 'iknow_params'

RSpec.describe ParamSerializers do
  describe 'TimeInZone' do
    let(:zone_name) { 'Asia/Tokyo' }
    subject { ParamSerializers::TimeInZone.new(zone_name) }

    context 'dumping' do
      it 'dumps a valid value' do
        t = Time.parse('2020-01-01 00:00:00 UTC')
        expect(subject.dump(t)).to eq('2020-01-01 09:00:00')
      end

      it 'raises on an invalid value' do
        expect { subject.dump('cheese') }.to raise_error(ParamSerializers::DumpError)
      end
    end

    context 'loading' do
      it 'loads the supported zone formats' do
        expected = Time.parse('2020-01-01 00:00:00 UTC')
        expect(subject.load('2020-01-01 00:00:00 UTC')).to eq(expected)
        expect(subject.load('2020/01/01 00:00:00 UTC')).to eq(expected)
        expect(subject.load('2020-01-01T00:00:00Z')).to eq(expected)
        expect(subject.load('2020-01-01 09:00:00')).to eq(expected)
        expect(subject.load('2020/01/01 09:00:00')).to eq(expected)
      end

      it 'raises on invalid values' do
        expect { subject.load('12:57:00') }.to raise_error(ParamSerializers::LoadError)
        expect { subject.load(1000) }.to raise_error(ParamSerializers::LoadError)
      end
    end
  end
end
