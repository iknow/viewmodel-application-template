# frozen_string_literal: true

# rubocop:disable Lint/NestedMethodDefinition, Lint/MissingCopEnableDirective

module ParamSerializers
  def self.get_namespace(base_ns, *parts)
    parts.reduce(base_ns) do |current_ns, part|
      if current_ns.const_defined?(part, false)
        current_ns.const_get(part, false)
      else
        Module.new.tap { |m| current_ns.const_set(part, m) }
      end
    end
  end

  # For each acts_as_enum model, we want to define a pair of serializers
  # ParamSerializers::T and ParamSerializers::T::Insensitive. Called from
  # ApplicationRecord on acts_as_enum initialization.
  def self.register_enum_serializer(enum_class)
    ancestor_path   = enum_class.name.deconstantize.split('::').drop_while(&:empty?).map(&:to_sym)
    serializer_name = enum_class.name.demodulize.to_sym
    target_ns       = get_namespace(ParamSerializers, *ancestor_path)

    serializer = ::Class.new(IknowParams::Serializer::ActsAsEnum) do
      target_ns.send(:remove_const, serializer_name) if target_ns.const_defined?(serializer_name, false)
      target_ns.const_set(serializer_name, self)

      define_method(:initialize) { super(enum_class) }
      set_singleton!
    end

    ::Class.new(IknowParams::Serializer::ActsAsEnum) do
      class_name = :Insensitive
      serializer.send(:remove_const, class_name) if serializer.const_defined?(class_name, false)
      serializer.const_set(:Insensitive, self)

      define_method(:initialize) { super(enum_class) }

      def load(str)
        unless str.is_a?(String)
          raise IknowParams::Serializer::LoadError.new("Invalid #{clazz.name} member: '#{str}' (not a String)")
        end

        constant = clazz.value_of(str, insensitive: true)

        if constant.nil?
          raise IknowParams::Serializer::LoadError.new("Invalid #{clazz.name} member: '#{str}' (case-insensitive)")
        end
        constant
      end

      set_singleton!
    end
  end

  def self.const_missing(name)
    IknowParams::Serializer.const_get(name)
  end

  class SignedInteger < IknowParams::Serializer::Integer
    def initialize(negative: true, zero: true, positive: true)
      super()
      @allow_negative = negative
      @allow_positive = positive
      @allow_zero = zero
    end

    def load(str)
      val = super
      matches_type!(val, err: LoadError)
      val
    end

    def matches_type?(val)
      return false unless super

      if val < 0
        @allow_negative
      elsif val == 0
        @allow_zero
      else
        @allow_positive
      end
    end

    json_value!
  end

  class LowercaseRenum < IknowParams::Serializer::Renum
    def load(str)
      if str.nil?
        raise LoadError.new('Invalid null enumeration constant')
      end

      val = clazz.with_insensitive_name(str)

      if val.nil?
        raise LoadError.new("Invalid enumeration constant: '#{str}'")
      end

      val
    end
  end

  class Class < IknowParams::Serializer
    attr_reader :superclass

    def initialize(superclass = ::Object)
      @superclass = superclass
      super(::Class)
    end

    def load(str)
      str.constantize.tap { |clazz| matches_type!(clazz, err: LoadError) }
    rescue NameError
      raise IknowParams::Serializer::LoadError.new("Invalid class name: #{str}")
    end

    def dump(clazz, json: nil)
      matches_type!(clazz)
      clazz.name
    end

    def matches_type?(val)
      super && val < superclass
    end

    set_singleton!
  end

  class ModelClass < Class
    def initialize
      super(ApplicationRecord)
    end

    set_singleton!
  end

  class ViewModelClass < Class
    def initialize
      super(ViewModel::Record)
    end

    def load(view_name)
      ViewModel::Registry.for_view_name(view_name)
    rescue ViewModel::DeserializationError::UnknownView
      raise IknowParams::Serializer::LoadError.new("Invalid viewmodel name: #{view_name}")
    end

    def dump(clazz, json: nil)
      matches_type!(clazz)
      clazz.view_name
    end

    set_singleton!
  end

  class Point < IknowParams::Serializer
    def initialize
      super(::ActiveRecord::Point)
    end

    def load(structure)
      unless structure.is_a?(Hash) && structure.keys.sort == ['x', 'y']
        raise IknowParams::Serializer::LoadError.new("Invalid point: #{structure.inspect}")
      end

      ::ActiveRecord::Point.new(structure['x'], structure['y'])
    end

    def dump(point, json: false)
      matches_type!(point)

      structure = { 'x' => point.x, 'y' => point.y }

      if json
        structure
      else
        JSON.dump(structure)
      end
    end

    set_singleton!
  end

  # Ranges load and dump the structure { min: x, max: y } representing an either
  # an inclusive or exclusive range (but not both). An unbounded range is
  # specified with a bound of 'null', and parsed into a Range with bound of
  # -Infinity or Infinity (which then is consumed by PostgreSQL as an unbounded
  # range).
  class Range < IknowParams::Serializer
    attr_reader :member_serializer, :schema, :exclude_end

    def initialize(member_serializer, member_schema: { 'type' => 'number' }, exclude_end: false)
      super(::Range)
      @member_serializer = member_serializer
      @exclude_end = exclude_end
      @schema = JsonSchema.parse!(
        {
          'type' => 'object',
          'additionalProperties' => false,
          'properties' => {
            'min' => { 'oneOf' => [{ 'type' => 'null' }, member_schema] },
            'max' => { 'oneOf' => [{ 'type' => 'null' }, member_schema] },
          },
          'required' => %w[min max],
        })
    end

    def load(structure)
      if structure.is_a?(::String)
        structure =
          begin
            JSON.parse(structure)
          rescue JSON::ParserError => e
            raise IknowParams::Serializer::LoadError.new("Invalid JSON while parsing range: #{e.message}")
          end
      elsif structure.is_a?(ActionController::Parameters)
        structure = structure.to_unsafe_h
      end

      valid, errors = schema.validate(structure)
      unless valid
        raise IknowParams::Serializer::LoadError.new(
                'Invalid range: ' +
                errors.map { |e| "#{e.pointer}: #{e.message}" }.join('; '))
      end

      min = structure['min'].try { |v| member_serializer.load(v) } || surrogate_negative_infinity
      max = structure['max'].try { |v| member_serializer.load(v) } || surrogate_infinity

      if !min.nil? && !max.nil? && min > max
        raise IknowParams::Serializer::LoadError.new(
                "Invalid range '#{min}..#{max}': lower bound must be less than or equal to upper bound")
      end

      ::Range.new(min, max, exclude_end)
    end

    def dump(range, json: false)
      infinite_start = infinite_bound?(range.begin, start: true)
      infinite_end   = infinite_bound?(range.end, start: false)

      if !infinite_start && !infinite_end && range.begin > range.end
        raise IknowParams::Serializer::DumpError.new(
                "Invalid range '#{range}': lower bound must be less than or equal to upper bound")
      end

      min_value = range.begin

      # If the range's end-inclusivity doesn't match the serializer, and it
      # cannot be normalized to include it (not infinite or integer typed), it
      # cannot be losslessly serialized with this serializer.
      max_value =
        case
        when infinite_end
          nil
        when range.exclude_end? && !exclude_end
          if integral?
            range.end - 1
          else
            raise IknowParams::Serializer::DumpError.new(
                    "Invalid range '#{range}': cannot serialize a non-integral exclusive range as inclusive")
          end
        when !range.exclude_end? && exclude_end
          if integral?
            range.end + 1
          else
            raise IknowParams::Serializer::DumpError.new(
                    "Invalid range '#{range}': cannot serialize a non-integral inclusive range as exclusive")
          end
        else
          range.end
        end

      min = infinite_start ? nil : member_serializer.dump(min_value, json: true)
      max = infinite_end   ? nil : member_serializer.dump(max_value, json: true)

      structure = { 'min' => min, 'max' => max }

      if json
        structure
      else
        JSON.dump(structure)
      end
    end

    private

    # Can we exclude a range end in this type by subtracting 1 from its value
    def integral?
      false
    end

    def surrogate_infinity
      ::Float::INFINITY
    end

    def surrogate_negative_infinity
      -::Float::INFINITY
    end

    def infinite_bound?(bound, start: false)
      # Handle native Ruby unbounded ranges and infinite values
      return true if bound.nil?

      # Otherwise fall back to matching our surrogates
      if start
        bound == surrogate_negative_infinity
      else
        bound == surrogate_infinity
      end
    end

    json_value!
  end

  class DateRange < Range
    def initialize(exclude_end: false)
      super(IknowParams::Serializer::Date, member_schema: { 'type' => 'string', 'format' => 'date' }, exclude_end:)
    end

    private

    # Construct proper begin/end-less ranges with nil bounds, as date ranges may
    # not be lower-bounded with -Infinity. Requires the model's attribute type
    # to be configured as Types::NilBoundedRange to handle the database side of
    # the serialization.
    def surrogate_infinity
      nil
    end

    def surrogate_negative_infinity
      nil
    end

    def integral?
      true
    end
  end

  class InclusiveDateRange < DateRange
    def initialize
      super(exclude_end: false)
    end

    set_singleton!
  end

  class ExclusiveDateRange < DateRange
    def initialize
      super(exclude_end: true)
    end

    set_singleton!
  end

  # A timestamp accurate to seconds
  class Time < IknowParams::Serializer::Time
    def load(str)
      return ::Time.now.utc.change(nsec: 0) if str == 'now'

      time = super

      unless time.nsec.zero?
        raise IknowParams::Serializer::LoadError.new(
                'Invalid timestamp: sub-second precision is not permitted')
      end

      time
    end

    set_singleton!
  end

  # Parses or serializes a timestamp representation in a specific time zone. The
  # parsed time is returned as the equivalent UTC Time object.
  class TimeInZone < IknowParams::Serializer
    OUTPUT_FORMAT = '%Y-%m-%d %H:%M:%S'
    INPUT_FORMATS = [
      # Time with explicit zone
      # Must be first, because strptime only matches string prefixes
      '%Y-%m-%dT%H:%M:%S%z',
      '%Y-%m-%d %H:%M:%S %z',
      '%Y/%m/%d %H:%M:%S %z',

      # Time with implicit zone
      OUTPUT_FORMAT,
      '%Y/%m/%d %H:%M:%S',
    ].freeze

    attr_reader :zone_name

    def initialize(zone_name)
      @zone_name = zone_name
      super(::Time)
    end

    def dump(val, json: nil)
      matches_type!(val)
      t = val.in_time_zone(zone_name)
      t.strftime(OUTPUT_FORMAT)
    end

    def load(str)
      raise LoadError.new('Invalid TimeInZone: not a String') unless str.is_a?(::String)

      zone = ::Time.find_zone(zone_name)
      raise LoadError.new('Could not parse TimeInZone: invalid timezone') unless zone

      zone_time = nil

      INPUT_FORMATS.each do |format|
        zone_time = zone.strptime(str, format)
        break if zone_time
      rescue ArgumentError => _e
        nil
      end

      unless zone_time
        raise LoadError.new('Invalid TimeInZone: could not detect a valid datetime format')
      end

      zone_time.utc
    end
  end

  class TimeRange < Range
    SCHEMA = {
      'oneOf' => [
        { 'type' => 'string', 'format' => 'date-time' },
        { 'type' => 'string', 'enum' => ['now'] },
      ],
    }.freeze

    def initialize(exclude_end: false)
      super(ParamSerializers::Time, member_schema: SCHEMA, exclude_end:)
    end

    private

    def surrogate_infinity
      nil
    end

    def surrogate_negative_infinity
      nil
    end
  end

  class InclusiveTimeRange < TimeRange
    def initialize
      super(exclude_end: false)
    end

    set_singleton!
  end

  class ExclusiveTimeRange < TimeRange
    def initialize
      super(exclude_end: true)
    end

    set_singleton!
  end

  # A timestamp accurate to microseconds, which matches the time resolution of
  # Postgres timestamps
  class AccurateTime < IknowParams::Serializer::Time
    def dump(val, json: nil)
      matches_type!(val)
      val.iso8601(6)
    end

    def load(str)
      return Time.now.utc if str == 'now'

      time = super

      unless (time.nsec % 1000).zero?
        # We believe this ought to reject the value, but we don't want to do
        # this until we're confident the frontend isn't using
        # incorrect-precision times.
        nsec = (time.nsec / 1000) * 1000
        time = time.change(nsec:)
      end

      time
    end

    set_singleton!
  end

  class AccurateTimeRange < Range
    def initialize(exclude_end: false)
      super(ParamSerializers::AccurateTime, member_schema: TimeRange::SCHEMA, exclude_end:)
    end

    private

    def surrogate_infinity
      nil
    end

    def surrogate_negative_infinity
      nil
    end
  end

  class InclusiveAccurateTimeRange < AccurateTimeRange
    def initialize
      super(exclude_end: false)
    end

    set_singleton!
  end

  class ExclusiveAccurateTimeRange < AccurateTimeRange
    def initialize
      super(exclude_end: true)
    end

    set_singleton!
  end

  class IntegerRange < Range
    def initialize(exclude_end: false)
      super(IknowParams::Serializer::Integer, member_schema: { 'type' => 'integer' }, exclude_end:)
    end

    private

    def integral?
      true
    end
  end

  class InclusiveIntegerRange < IntegerRange
    def initialize
      super(exclude_end: false)
    end

    set_singleton!
  end

  class ExclusiveIntegerRange < IntegerRange
    def initialize
      super(exclude_end: true)
    end

    set_singleton!
  end

  class BigDecimal < IknowParams::Serializer
    def initialize
      super(::BigDecimal)
    end

    def load(str)
      BigDecimal(str)
    rescue TypeError, ArgumentError => _e
      raise LoadError.new('Invalid type for conversion to BigDecimal')
    end

    def dump(val, json: false)
      matches_type!(val)
      val.to_s('F')
    end

    set_singleton!
  end

  class Timezone < IknowParams::Serializer
    def initialize
      super(::TZInfo::InfoTimezone)
    end

    def load(str)
      zone = TZInfo::Timezone.get(str)
      zone = zone.canonical_zone
      zone
    rescue TZInfo::InvalidTimezoneIdentifier
      raise LoadError.new("Invalid timezone: #{str}")
    end

    def dump(zone, json: nil)
      matches_type!(zone)
      zone = zone.canonical_zone
      zone.identifier
    end

    set_singleton!
  end

  class SimpleDuration < IknowParams::Serializer::Duration
    attr_reader :allowed_parts

    def initialize(allowed_parts = SimpleDurationValidator::DEFAULT_PART_GROUPS)
      super()
      @allowed_parts = allowed_parts
    end

    def matches_type?(val)
      super && SimpleDurationValidator.check_parts(val, allowed_parts:).nil?
    end

    def matches_type!(val, err: IknowParams::Serializer::DumpError)
      unless val.is_a?(ActiveSupport::Duration)
        raise err.new("Incorrect type for #{self.class.name}: #{val.inspect}:#{val.class.name}")
      end

      result = SimpleDurationValidator.check_parts(val, allowed_parts:)

      if result == :complex_duration
        raise err.new("#{self.class.name} may not include a mixture of months, days and seconds")
      end

      if result == :invalid_parts
        raise err.new("#{self.class.name} may only include parts compatible with #{@allowed_parts.join(',')}")
      end

      true
    end

    def load(str)
      duration = super
      matches_type!(duration, err: IknowParams::Serializer::LoadError)
      duration
    end

    set_singleton!
  end

  class FixedDuration < SimpleDuration
    def initialize
      super([:seconds])
    end

    set_singleton!
  end

  class UnixTimestamp < IknowParams::Serializer::Time
    def load(str)
      unix_time = IknowParams::Serializer::Integer.load(str)
      begin
        clazz.at(unix_time).utc
      rescue TypeError
        raise LoadError.new("Invalid type for conversion to #{clazz}")
      end
    end

    def dump(val, json: false)
      matches_type!(val)
      IknowParams::Serializer::Integer.dump(val.to_i, json:)
    end

    set_singleton!
  end


  class UnixTimestampMilliseconds < IknowParams::Serializer::Time
    def load(str)
      unix_time = IknowParams::Serializer::Integer.load(str)
      begin
        clazz.at(unix_time / 1000.0).utc
      rescue TypeError
        raise LoadError.new("Invalid type for conversion to #{clazz}")
      end
    end

    def dump(val, json: false)
      matches_type!(val)
      IknowParams::Serializer::Integer.dump((val.to_f * 1000.0).to_i, json:)
    end

    set_singleton!
  end

  class SearchDirection < IknowParams::Serializer::StringEnum
    def initialize
      super('asc', 'desc')
    end
    json_value!
    set_singleton!
  end

  class URI < IknowParams::Serializer
    def initialize
      super(::URI)
    end

    def load(str)
      ::URI.parse(str)
    rescue ::URI::InvalidURIError => ex
      raise LoadError.new("Invalid URI: #{ex}")
    end

    set_singleton!
  end

  # Similar to IknowParams::Serializer::Nullable, but suitable for query params
  # parsing rather than JSON parsing, as it handles surrogate "null" String
  # values.
  class Optional < IknowParams::Serializer::Nullable
    SURROGATES = ['', 'null', 'nil'].freeze

    def load(str)
      if str.is_a?(::String) && SURROGATES.any? { |surr| surr.casecmp?(str) }
        str = nil
      end

      super(str)
    end

    def dump(val, json: false)
      result = super

      if !json && result.nil?
        'null'
      else
        result
      end
    end
  end

  class OptionalBoolean < Optional
    def initialize
      super(IknowParams::Serializer::Boolean)
    end

    def load(str)
      if str.is_a?(::String) && str.casecmp?('both')
        nil
      else
        super
      end
    end

    set_singleton!
  end

  class LowercaseString < IknowParams::Serializer::String
    def load(string)
      super.downcase
    end
  end

  class Base64 < IknowParams::Serializer
    def initialize
      super(::String)
    end

    def load(b64str)
      ::Base64.strict_decode64(b64str)
    rescue ArgumentError => e
      raise LoadError.new("Invalid base64: #{e}")
    end

    def dump(val, json: false)
      matches_type!(val)
      ::Base64.strict_encode64(val)
    end

    set_singleton!
  end

  class Base16 < IknowParams::Serializer
    def initialize
      super(::String)
    end

    def load(hex)
      BaseX::Base16.decode(hex)
    rescue BaseX::InvalidNumeral => e
      raise LoadError.new("Invalid hex: #{e}")
    end

    def dump(val, json: false)
      matches_type!(val)
      BaseX::Base16.encode(val)
    end

    set_singleton!
  end

  class ContentType < IknowParams::Serializer
    def initialize
      super(::ContentType)
    end

    def load(string)
      ::ContentType.parse(string)
    rescue ::ContentType::InvalidContentType => e
      raise LoadError.new("Invalid content type: #{e}")
    end

    def dump(val, json: false)
      matches_type!(val)
      val.to_s
    end

    set_singleton!
  end

  class JsonFilterQuery < IknowParams::Serializer::JsonWithSchema::Rails
    PATH = /\A[A-z0-9]+(?:\.[A-z0-9]+)*\z/
    SCHEMA = JsonSchemaHelper.build do
      {
        type: 'object',
        additionalProperties: false,
        patternProperties: {
          PATH => any_of(
            string, number, boolean, null,
            {
              type: 'object',
              additionalProperties: false,
              minProperties: 1,
              properties: {
                eq:  any_of(string, number, boolean, null),
                gt:  any_of(string, number),
                lt:  any_of(string, number),
                gte: any_of(string, number),
                lte: any_of(string, number),
              },
            }
          ),
        },
      }
    end

    def initialize
      super(SCHEMA)
    end

    def load(structure)
      convert_numeric_terminals(super)
    end

    private

    # Rails query parameters only allow passing values as strings. We want to be
    # able to easily match primitive types, so parse strings corresponding to
    # numbers/booleans/null. This does come at the cost of not being able to
    # represent the strings 'true', 'false' and 'null', even using a JSON
    # request body.
    def convert_numeric_terminals(json)
      case json
      when 'true'
        true
      when 'false'
        false
      when 'null'
        nil
      when ::String
        Integer(json, exception: false) || Float(json, exception: false) || json
      when ::Array
        json.map { |val| convert_numeric_terminals(val) }
      when ::Hash
        json.transform_values { |val| convert_numeric_terminals(val) }
      else
        json
      end
    end

    set_singleton!
  end

  # Specialized serializer combinator that swallows LoadErrors and returns nil.
  # Useful specifically for loading existing values of ActsAsEnum attributes:
  # they will be resynchronized once loaded, so if previous values are
  # unreadable we can simply rely on synchronization to overwrite them.
  class BestEffort < IknowParams::Serializer
    def initialize(serializer)
      super(serializer.clazz)
      @serializer = serializer
    end

    delegate :dump, :matches_type?, :matches_type!, to: :@serializer

    def load(jval)
      @serializer.load(jval)
    rescue LoadError
      nil
    end
  end

  class ArrayOf < IknowParams::Serializer::ArrayOf
    attr_reader :allow_empty, :unique

    json_value!

    def initialize(serializer, allow_singleton: false, allow_empty: true, unique: false)
      super(serializer, allow_singleton:)
      @allow_empty = allow_empty
      @unique = unique
    end

    def load(jvals)
      result = super

      if unique
        result = result.uniq
      end

      if result.empty? && !allow_empty
        raise LoadError.new('Invalid array parameter: must not be empty')
      end

      result
    end

    def matches_type?(vals)
      return false unless super
      return false if !allow_empty && vals.empty?
      return false if unique && vals != vals.uniq

      true
    end
  end

  class QueryCollectionOf < ArrayOf
    def initialize(type)
      super(type, allow_singleton: true, allow_empty: false)
    end
  end

  class UploadedFile < IknowParams::Serializer
    def initialize
      super(ActionDispatch::Http::UploadedFile)
    end

    def load(param)
      matches_type!(param, err: LoadError)
      param
    end

    def dump(_value, json:)
      raise DumpError.new('Cannot dump uploaded file')
    end

    set_singleton!
  end

  # A load-only serializer for a parameter that may be either a single X or a non-empty array of X
  class OneOrMany < IknowParams::Serializer
    def initialize(serializer)
      super(Object)
      @serializer = serializer
      @array_serializer = ArrayOf.new(serializer, allow_singleton: false, allow_empty: false)
    end

    def load(value)
      @array_serializer.load(value)
    rescue IknowParams::Serializer::LoadError
      @serializer.load(value)
    end
  end

  class Encoding < IknowParams::Serializer
    def initialize
      super(::Encoding)
    end

    def load(value)
      ::Encoding.find(value)
    rescue ArgumentError
      raise LoadError.new("Invalid content type: #{e}")
    end

    def dump(val)
      matches_type!(val)
      val.name
    end

    json_value!
    set_singleton!
  end
end
