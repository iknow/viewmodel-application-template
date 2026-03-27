# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PasswordRule do
  context 'minimum length' do
    let(:rule) { PasswordRule.new(min_length: 6) }

    it 'rejects violations' do
      errors = rule.validate('cat')
      expect(errors).to be_present
      expect(PasswordRule::Errors.to_h(errors)).to include(minlength: 6)
    end

    it 'permits non-violations' do
      errors = rule.validate('catcat')
      expect(errors).to be_nil
    end

    describe '#validate?' do
      it 'returns a boolean' do
        expect(rule.validate?('cat')).to be(false)
        expect(rule.validate?('catcat')).to be(true)
      end
    end
  end

  context 'maximum consecutive' do
    let(:rule) { PasswordRule.new(max_consecutive: 3) }

    it 'rejects violations' do
      errors = rule.validate('abccccd')
      expect(errors).to be_present
      expect(PasswordRule::Errors.to_h(errors)).to include(max_consecutive: 3)
    end

    it 'permits non-violations' do
      errors = rule.validate('abccdcce')
      expect(errors).to be_nil
    end
  end

  context 'allowed classes' do
    let(:rule) do
      PasswordRule.new(allowed: [PasswordRule::Classes::Upper, PasswordRule::Classes::Digit])
    end

    it 'rejects violations' do
      errors = rule.validate('C@TS')
      expect(errors).to be_present
      expect(PasswordRule::Errors.to_h(errors)).to include(allowed: ['upper', 'digit'])
    end

    it 'permits non-violations' do
      errors = rule.validate('C4TS')
      expect(errors).to be_nil
    end
  end

  context 'required classes' do
    let(:required_classes) do
      [
        PasswordRule::Classes::Lower,
        [PasswordRule::Classes::Upper, PasswordRule::Classes::Digit],
      ]
    end

    let(:rule) do
      PasswordRule.new(required: required_classes)
    end

    it 'rejects violations' do
      errors = rule.validate('DOG')
      expect(errors).to be_present
      expect(PasswordRule::Errors.to_h(errors)).to include(required: [['lower']])
    end

    it 'rejects violations in optional classes' do
      errors = rule.validate('dog')
      expect(errors).to be_present
      expect(PasswordRule::Errors.to_h(errors)).to include(required: [['upper', 'digit']])
    end

    it 'permits any of optional classes' do
      errors = rule.validate('doG')
      expect(errors).to be_nil

      errors = rule.validate('d0g')
      expect(errors).to be_nil
    end

    it 'rejects characters outside the classes' do
      errors = rule.validate('c@T')
      expect(errors).to be_present
      expect(PasswordRule::Errors.to_h(errors)).to include(allowed: ['lower', 'upper', 'digit'])
    end

    context 'with additional allowed classes' do
      let(:rule) do
        PasswordRule.new(
          allowed: [PasswordRule::Classes::Special],
          required: required_classes)
      end

      it 'permits characters in the additional classes' do
        errors = rule.validate('c@T')
        expect(errors).to be_nil
      end
    end
  end
end
