# frozen_string_literal: true

# Originally from https://gist.github.com/ssimeonov/6519423#file-enum_validator-rb-L45-L54
# But rewritten because it was gross. Errors got more complicated, so rewriting them is also cut.

# Validates the values of an Array with other validators.
#
# Example:
#
#   validates :an_array, array: { presence: true, inclusion: { in: %w{ big small } } }
#

class ArrayValidator < ActiveModel::EachValidator
  # Things that configure local behavior, and are not validators
  LOCAL_OPTIONS = [:allow_nil_elements, :allow_blank_elements].freeze

  def initialize(options)
    super(options)

    klass = options.delete(:class) # the class we're being attached to
    validators = options.slice!(*klass.send(:_validates_default_keys) + LOCAL_OPTIONS)

    @element_validators = validators.map do |key, args|
      opts = { attributes:, class: klass, **options }
      opts.merge!(args) if args.kind_of?(Hash)

      validator_class_name = "#{key.to_s.camelize}Validator"
      validator_class = ActiveModel::Validations.const_get(validator_class_name)

      validator_class.new(opts).tap do |validator|
        validator.check_validity!
      end
    end
  end

  def validate_each(record, attribute, values)
    unless values.is_a?(Array)
      record.errors.add(attribute, :not_array, message: 'must be an array')
      return
    end

    values.each_with_index do |value, index|
      next if value.nil? && options[:allow_nil_elements]
      next if value.blank? && options[:allow_blank_elements]

      @element_validators.each do |validator|
        validator.validate_each(record, attribute, value)
      end
    end
  end
end
