# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TypeValidator do
  let(:test_model) do
    type_rule = rule
    Class.new do
      include ActiveModel::Model
      def self.model_name
        ActiveModel::Name.new(self, nil, 'TestModel')
      end

      attr_accessor :field
      validates :field, type: type_rule
    end
  end

  context 'single value' do
    let(:rule) { { is_a: Integer } }

    it 'admits an integer' do
      expect(test_model.new(field: 3)).to be_valid
    end

    it 'rejects a float' do
      expect(test_model.new(field: 1.5)).not_to be_valid
    end

    it 'rejects nil' do
      expect(test_model.new(field: nil)).not_to be_valid
    end
  end

  context 'nullable value' do
    let(:rule) { { is_a: Float, allow_nil: true } }

    it 'admits a float' do
      expect(test_model.new(field: 1.5)).to be_valid
    end

    it 'rejects an integer' do
      expect(test_model.new(field: 3)).not_to be_valid
    end

    it 'admits nil' do
      expect(test_model.new(field: nil)).to be_valid
    end
  end

  context 'array' do
    let(:rule) { { array_of: { is_a: Integer } } }

    it 'admits an empty array' do
      expect(test_model.new(field: [])).to be_valid
    end

    it 'admits an array of integers' do
      expect(test_model.new(field: [1, 2, 3])).to be_valid
    end

    it 'rejects an array with a float' do
      expect(test_model.new(field: [1, 2.5, 3])).not_to be_valid
    end

    it 'rejects an array with nil' do
      expect(test_model.new(field: [1, nil, 3])).not_to be_valid
    end

    it 'rejects nil' do
      expect(test_model.new(field: nil)).not_to be_valid
    end
  end

  context 'hash' do
    let(:rule) { { hash_from: { is_a: String }, to: { is_a: Integer } } }

    it 'admits an empty hash' do
      expect(test_model.new(field: {})).to be_valid
    end

    it 'admits a hash from string to integer' do
      expect(test_model.new(field: { 'a' => 1, 'b' => 2 })).to be_valid
    end

    it 'rejects a hash with an integer key' do
      expect(test_model.new(field: { 1 => 2 })).not_to be_valid
    end

    it 'rejects a hash with a string value' do
      expect(test_model.new(field: { 'a' => 'b' })).not_to be_valid
    end

    it 'rejects nil' do
      expect(test_model.new(field: nil)).not_to be_valid
    end
  end

  context 'nullable array' do
    let(:rule) { { array_of: { is_a: Integer }, allow_nil: true } }

    it 'admits an empty array' do
      expect(test_model.new(field: [])).to be_valid
    end

    it 'admits an array of integers' do
      expect(test_model.new(field: [1, 2, 3])).to be_valid
    end

    it 'rejects an array with a float' do
      expect(test_model.new(field: [1, 2.5, 3])).not_to be_valid
    end

    it 'rejects an array with nil' do
      expect(test_model.new(field: [1, nil, 3])).not_to be_valid
    end

    it 'admits nil' do
      expect(test_model.new(field: nil)).to be_valid
    end
  end

  context 'array of nullable' do
    let(:rule) { { array_of: { is_a: Integer, allow_nil: true } } }

    it 'admits an empty array' do
      expect(test_model.new(field: [])).to be_valid
    end

    it 'admits an array of integers' do
      expect(test_model.new(field: [1, 2, 3])).to be_valid
    end

    it 'rejects an array with a float' do
      expect(test_model.new(field: [1, 2.5, 3])).not_to be_valid
    end

    it 'admits an array with nil' do
      expect(test_model.new(field: [1, nil, 3])).to be_valid
    end

    it 'rejects nil' do
      expect(test_model.new(field: nil)).not_to be_valid
    end
  end

  context 'array of array' do
    let(:rule) { { array_of: { array_of: { is_a: Integer } } } }

    it 'admits an empty array' do
      expect(test_model.new(field: [])).to be_valid
    end

    it 'admits an array of arrays of integers' do
      expect(test_model.new(field: [[1], [2, 3]])).to be_valid
    end

    it 'rejects an array with integers' do
      expect(test_model.new(field: [1, 2])).not_to be_valid
    end

    it 'rejects nil' do
      expect(test_model.new(field: nil)).not_to be_valid
    end
  end
end
