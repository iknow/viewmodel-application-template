# frozen_string_literal: true

class PasswordRule
  enum :Classes do
    Lower(/[a-z]/)
    Upper(/[A-Z]/)
    Digit(/[0-9]/)
    Special(/[-~!@#$%^&\*\_+=`|(){}\[\]:;"'<>,.? ]/)
    AsciiPrintable(/(?=\p{ASCII})\p{Print}/)
    Unicode(/\p{Print}/)

    attr_reader :regex

    def init(regex)
      @regex = regex
    end

    def constant
      name.downcase
    end
  end

  module Errors
    def self.to_s(errors)
      'did not conform to password rules: ' +
        errors.map(&:message).join('; ')
    end

    # Merge the hashes of the provided errors
    def self.to_h(errors)
      errors.map(&:to_h).each_with_object({}) do |err_h, h|
        err_h.each do |type, val|
          if (existing_val = h[type])
            # we assert that the value for any error type which can appear
            # more than once be combined with `:+`
            val = existing_val + val
          end

          h[type] = val
        end
      end
    end

    class Required
      def initialize(missing_classes)
        @missing_classes = missing_classes
      end

      def message
        'must include ' + @missing_classes.map { |c| "'#{c.constant}'" }.join(' or ')
      end

      def to_h
        { required: [@missing_classes.map(&:constant)] }
      end
    end

    class Allowed
      def initialize(allowed_classes)
        @allowed_classes = allowed_classes
      end

      def message
        'may only include the following characters: ' + @allowed_classes.map { |c| "'#{c.constant}'" }.join(', ')
      end

      def to_h
        { allowed: @allowed_classes.map(&:constant) }
      end
    end

    class MinLength
      def initialize(length)
        @length = length
      end

      def message
        "must be longer than #{@length} characters"
      end

      def to_h
        { minlength: @length }
      end
    end

    class MaxConsecutive
      def initialize(length)
        @length = length
      end

      def message
        "must not have more than #{@length} consecutive characters"
      end

      def to_h
        { max_consecutive: @length }
      end
    end
  end

  attr_reader :required, :allowed, :max_consecutive, :min_length, :effective_allowed

  def initialize(required: [], allowed: [], max_consecutive: nil, min_length: nil)
    @required        = Array.wrap(required).map { |classes| Array.wrap(classes) }.freeze
    @allowed         = Array.wrap(allowed).dup.freeze
    @max_consecutive = max_consecutive
    @min_length      = min_length

    @effective_allowed = required.flatten.concat(allowed).uniq.tap do |cs|
      cs << Classes::AsciiPrintable if cs.empty?
    end
  end

  def to_s
    clauses = []

    required.each do |required_classes|
      class_string = Array.wrap(required_classes).map(&:constant).join(', ')
      clauses << "required: #{class_string};"
    end

    allowed.each do |allowed_class|
      clauses << "allowed: #{allowed_class.constant};"
    end

    if max_consecutive
      clauses << "max-consecutive: #{max_consecutive};"
    end

    if min_length
      clauses << "minlength: #{min_length};"
    end

    clauses.join(' ')
  end

  def to_h
    {}.tap do |h|
      unless required.empty?
        h['required'] = required.map { |g| g.map(&:constant) }
      end

      unless allowed.empty?
        h['allowed'] = allowed.map(&:constant)
      end

      h['max-consecutive'] = max_consecutive if max_consecutive
      h['minlength']       = min_length      if min_length
    end
  end

  def validate(password)
    errors = []

    unless length_valid?(password)
      errors << Errors::MinLength.new(min_length)
    end

    unless max_consecutive_valid?(password)
      errors << Errors::MaxConsecutive.new(max_consecutive)
    end

    required.each do |required_classes|
      unless required_valid?(password, required_classes)
        errors << Errors::Required.new(required_classes)
      end
    end

    unless allowed_valid?(password)
      errors << Errors::Allowed.new(effective_allowed)
    end

    errors if errors.present?
  end

  def validate?(password)
    validate(password).nil?
  end

  private

  def length_valid?(password)
    return true unless min_length

    password.length >= min_length
  end

  def max_consecutive_valid?(password)
    return true unless max_consecutive

    max_found =
      password.each_char
        .slice_when { |a, b| a != b }
        .map(&:length)
        .max

    max_found <= max_consecutive
  end

  def required_valid?(password, classes)
    Array.wrap(classes).any? { |char_class| char_class.regex.match?(password) }
  end

  def allowed_valid?(password)
    password.each_char.all? do |c|
      effective_allowed.any? { |char_class| char_class.regex.match?(c) }
    end
  end
end
