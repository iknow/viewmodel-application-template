# frozen_string_literal: true

CsvColumn = Value.new(
  # Name of the column, as seen in the CSV
  :name,
  # Path to viewmodel attribute, or serialization function. Defaults to an
  # attribute with the same name as the column.
  serializer: :_undefined,
  # viewmodel path to attribute to deserialize or deserialization function.
  # Defaults to an attribute with the same name as the column. nil may be
  # specified to indicate deserialization is not supported for this column.
  deserializer: :_undefined,
  # IknowParam serializer for parsing/dumping the CSV string value
  format: ParamSerializers::String,
  # By default, we strip leading/trailing whitespace before passing the value to
  # the formatter. If it's ever semantic, this can be skipped.
  strip_whitespace: true,
  # The default value for the column, as a CSV string
  default: :_undefined,
  # Aggregate classes used by this column
  aggregates: [],
  # The names of deserialization crutches used by this column
  serialization_crutches: [],
  deserialization_crutches: [],
  # A deep preloader include spec for serialization
  eager_includes: DeepPreloader::Spec.new({}),
  # A description of the field for the CSV template comment (first line).
  # Blank if left nil.
  description: nil,
  # A type description or example usage of the field for the CSV template
  # comment (second line). Inferred from the format if left nil.
  example: nil,
)

class CsvColumn
  include ActiveModel::Validations

  @builder = KeywordBuilder.create(self, constructor: :with)

  class << self
    delegate :build!, to: :@builder

    def example_from_format(format)
      if format.nil?
        ''
      elsif format < ParamSerializers::ActsAsEnum
        enum_class = format.new.clazz
        if enum_class == Language
          public_language_ids = Language.values
            .map { |l| l.id }
          I18n.t('application_csv.formats.one_of', items: public_language_ids.join(', '))
        else
          ids = enum_class.values.map { |e| e.id }
          if ids.length > 10
            I18n.t('application_csv.formats.type', type: enum_class.name)
          else
            I18n.t('application_csv.formats.one_of', items: ids.join(', '))
          end
        end
      elsif format == ParamSerializers::Timezone
        I18n.t('application_csv.formats.timezone')
      elsif format == ParamSerializers::TimeInZone
        I18n.t('application_csv.formats.time_in_zone')
      elsif format == ParamSerializers::Date
        I18n.t('application_csv.formats.date')
      elsif format == ParamSerializers::Duration
        I18n.t('application_csv.formats.duration')
      elsif format == ParamSerializers::UUID
        I18n.t('application_csv.formats.uuid')
      elsif format == ParamSerializers::Boolean
        I18n.t('application_csv.formats.one_of', items: 'true, false')
      elsif format < ParamSerializers::Integer
        I18n.t('application_csv.formats.integer')
      elsif format < ParamSerializers::Numeric
        I18n.t('application_csv.formats.numeric')
      else
        ''
      end
    end
  end

  def initialize(name, serializer, deserializer, format, strip_whitespace, default, aggregates, serialization_crutches, deserialization_crutches, eager_includes, description, example)
    serializer = [name]   if serializer == :_undefined
    deserializer = [name] if deserializer == :_undefined
    eager_includes = DeepPreloader::Spec.parse(eager_includes)
    super(name, serializer, deserializer, format, strip_whitespace, default, aggregates, serialization_crutches, deserialization_crutches, eager_includes, description, example)
  end

  def has_default?
    default != :_undefined
  end

  def read_only?
    deserializer.nil?
  end

  def write_only?
    serializer.nil?
  end

  ARBITRARY_TIMEZONE = ParamSerializers::TimeInZone.new('utc')

  # Handle the special case format for timestamps
  def formatter_for(context)
    formatter = self.format
    return nil unless formatter

    if formatter == ParamSerializers::TimeInZone
      timezone = context.view_context_data(ARBITRARY_TIMEZONE)
      formatter.new(timezone)
    else
      formatter
    end
  rescue ApplicationView::MissingContextData
    raise ApplicationCsv::InternalError.new('Serialization timezone not configured')
  end

  SerializeEnv = Value.new(:view, :aggregates, :crutches, :serialize_context) do
    def model
      view.model
    end

    # Every defined crutch has an entry in row_crutches, but that entry may be
    # blank if the crutch contained no data
    def crutch(name, &)
      crutches.fetch(name) || (yield if block_given?)
    end
  end

  def template_description(i18n_scope)
    if self.description.nil?
      translation = I18n.t("#{self.name}.description", scope: i18n_scope, default: '')
      if translation.empty?
        nil
      else
        translation
      end
    elsif self.description.is_a?(Proc)
      self.description.call
    else
      self.description
    end
  end

  def template_example(i18n_scope)
    if self.example.nil?
      translation = I18n.t("#{self.name}.example", scope: i18n_scope, default: '')
      if translation.empty?
        CsvColumn.example_from_format(self.format)
      else
        translation
      end
    elsif self.example.is_a?(Proc)
      self.example.call
    else
      self.example
    end
  end

  def serialize(view, aggregates:, crutches:, serialize_context:)
    serializer = self.serializer || [name]

    value =
      if serializer.is_a?(Proc)
        env = SerializeEnv.with(view:, aggregates:, crutches:, serialize_context:)
        env.instance_exec(&serializer)
      else
        path = Array.wrap(serializer)
        path.inject(view) do |v, elt|
          case v
          when nil
            nil
          when ViewModel
            v.public_send(elt)
          else
            v[elt]
          end
        end
      end

    # Null values are represented as the empty string in CSV serialization (and
    # so are indistinguishable from actual empty strings)
    if value.nil?
      value = ''
    else
      formatter = formatter_for(serialize_context)
      value = formatter.dump(value, json: false) if formatter
    end

    value
  end

  def readable?
    !serializer.nil?
  end

  def writable?
    !deserializer.nil?
  end

  DeserializeEnv = Value.new(:row_id, :value, :update_data, :viewmodel_class, :crutches, :references, :deserialize_context) do
    def new?
      row_id.nil?
    end

    # Every defined crutch has an entry in row_crutches, but that entry may be
    # blank if the crutch contained no data
    def crutch(name, &)
      crutches.fetch(name) || (yield if block_given?)
    end
  end

  def deserialize(value, update_data, row_id:, viewmodel_class:, crutches:, references:, deserialize_context:)
    if read_only?
      raise RuntimeError.new('Trying to deserialize a read-only column')
    end

    if value
      # Deserialize the value from the raw CSV string, first by stripping
      # whitespace then passing it to the defined formatter.
      if strip_whitespace
        value = value.gsub(/\A\p{Space}+|\p{Space}+\z/, '')
      end

      if (formatter = formatter_for(deserialize_context))
        value = formatter.load(value)
      end
    end

    if deserializer.is_a?(Proc)
      env = DeserializeEnv.with(row_id:, value:, update_data:, viewmodel_class:, crutches:, references:, deserialize_context:)
      env.instance_exec(&deserializer)
    else
      path = Array.wrap(deserializer).map(&:to_s)
      attr_name = path.pop

      # deserialization specified with a path may only traverse single,
      # non-referenced associations, by creating `auto` children.
      path.each do |p|
        association_data = viewmodel_class._members[p]

        unless association_data && association_data.association?
          raise ApplicationCsv::AttributeStructureError.new(
                  "Invalid association in deserialization path: '#{p}'")
        end

        if association_data.referenced? || association_data.collection?
          raise ApplicationCsv::AttributeStructureError.new(
                  "Deserialization path may only follow single nested associations: #{p}")
        end

        target_view = association_data.viewmodel_class

        update_data[p] ||= {
          ViewModel::TYPE_ATTRIBUTE => target_view.view_name,
          ViewModel::NEW_ATTRIBUTE => 'auto',
          ViewModel::VERSION_ATTRIBUTE => target_view.schema_version,
        }

        update_data = update_data[p]
        viewmodel_class = target_view
      end

      member_data = viewmodel_class._members[attr_name]

      unless member_data && !member_data.association?
        raise ApplicationCsv::AttributeStructureError.new(
                "Deserialization attribute not found: '#{attr_name}'")
      end

      if member_data.attribute_viewmodel
        raise ApplicationCsv::AttributeStructureError.new(
                "Deserialization attribute has a viewmodel defined: '#{attr_name}'")
      end

      if value && member_data.attribute_serializer
        value = member_data.attribute_serializer.dump(value, json: true)
      end

      update_data[attr_name] = value
    end
  end
end
