# frozen_string_literal: true

# The dynamic columns available for a given entity are determined by which
# configuration partitioning it inhabits: for example for teacher metadata, this
# is its organization, whereas for group membership metadata it's its group. For
# consistency, this partitioning must be identified both on serialization and
# deserialization (although it would be alternatively be possible to identify
# during deserializion it based entirely on the contents of the CSV).
DynamicCsvColumns = Value.new(
  :name,

  # Given a controller request filters, identify which partitions the results
  # will be constrained to, and from that calculate and return the dynamic
  # columns that those partitions have in common. These may be returned either
  # as Strings representing the column names, or as arbitrary rich objects which
  # must respond to #name. These objects will be passed as a second argument
  # to the serialize/deserializer blocks.
  :define_columns,

  # column serialize function, taking a name and def.
  # If not defined, default to accessing the key `column_name` of the hash-typed attribute `name`.
  serializer: :_undefined,

  # column deserialize function, taking a name and def, or nil.
  # If not defined, default to writing to the key `column_name` of the hash-typed attribute `name`.
  deserializer: :_undefined,

  column_format: ParamSerializers::String,
  serialization_crutches: [],
  deserialization_crutches: [],
  aggregates: [],
  eager_includes: [])

class DynamicCsvColumns
  @builder = KeywordBuilder.create(self, constructor: :with)

  class << self
    delegate :build!, to: :@builder
  end

  def initialize(name, column_defs, serializer, deserializer, column_format, serialization_crutches, deserialization_crutches, aggregates, eager_includes)
    if serializer == :_undefined
      serializer = ->(column_def) do
        column_name = DynamicCsvColumns.column_def_name(column_def)
        view.public_send(name).try { |h| h[column_name.to_s] }
      end
    end

    if deserializer == :_undefined
      deserializer = ->(column_def) do
        column_name = DynamicCsvColumns.column_def_name(column_def)
        update_data[name] ||= {}
        update_data[name][column_name] = value
      end
    end

    super(name, column_defs, serializer, deserializer, column_format, serialization_crutches, deserialization_crutches, aggregates, eager_includes)
  end

  def column_defs(request_filters)
    self[:define_columns].call(request_filters)
  end

  def column_names(request_filters)
    column_defs(request_filters).map { |d| DynamicCsvColumns.column_def_name(d) }
  end

  def column_format(column_def)
    format = self[:column_format]
    if format.is_a?(Proc)
      format.call(column_def)
    else
      format
    end
  end

  def columns(request_filters)
    defs = column_defs(request_filters)

    defs.to_h do |column_def|
      column_name = DynamicCsvColumns.column_def_name(column_def)

      serializer     = self.serializer
      deserializer   = self.deserializer
      format         = self.column_format(column_def)
      aggregates     = self.aggregates
      eager_includes = self.eager_includes
      serialization_crutches   = self.serialization_crutches
      deserialization_crutches = self.deserialization_crutches

      csv_column = CsvColumn.build!(name: column_name.to_sym, format:, aggregates:, serialization_crutches:, deserialization_crutches:, eager_includes:) do
        serializer { instance_exec(column_def, &serializer) }

        if deserializer
          deserializer { instance_exec(column_def, &deserializer) }
        else
          deserializer nil
        end
      end

      [column_name, csv_column]
    end
  end

  def self.column_def_name(column_def)
    case column_def
    when String, Symbol
      column_def.to_s
    else
      column_def.name
    end
  end
end
