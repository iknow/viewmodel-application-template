# frozen_string_literal: true

require 'csv'

class ApplicationCsv
  class InternalError < ServiceError
    status 500
    code 'CSV.InternalError'
    attr_reader :detail

    def initialize(detail)
      @detail = detail
      super()
    end
  end

  class AttributeStructureError < InternalError
    code 'CSV.AttributeStructureError'
  end

  class CsvEmpty < ServiceError
    status 400
    code 'CSV.Empty'
    detail 'The uploaded CSV is empty'
  end

  class InvalidFilter < ServiceError
    status 400
    code 'CSV.InvalidFilter'
    attr_reader :detail

    def initialize(detail)
      @detail = detail
      super()
    end
  end

  class ColumnsError < ServiceError
    attr_reader :columns

    def initialize(columns)
      @columns = Array.wrap(columns).map(&:to_s)
      super()
    end

    def meta
      { columns: }
    end
  end

  class MissingAggregateRange < ColumnsError
    status 400
    code 'CSV.MissingAggregateRange'

    def detail
      "Aggregate columns were requested but no aggregate range was specified: #{columns}"
    end
  end

  class ReadOnlyColumns < ColumnsError
    status 400
    code 'CSV.ReadOnlyColumns'

    def detail
      "Cannot write to read only columns: #{columns}"
    end
  end

  class WriteOnlyColumns < ColumnsError
    status 400
    code 'CSV.WriteOnlyColumns'

    def detail
      "Cannot display write only columns: #{columns}"
    end
  end

  class InvalidColumns < ColumnsError
    status 400
    code 'CSV.InvalidColumns'

    attr_reader :valid_columns

    def initialize(columns, valid_columns)
      @valid_columns = valid_columns
      super(columns)
    end

    def detail
      "The following column names are not valid for this CSV: #{columns}"
    end

    def meta
      super.merge(valid_columns:)
    end
  end

  class DuplicateColumns < ColumnsError
    status 400
    code 'CSV.DuplicateColumns'

    def detail
      "Duplicate column names are not allowed: #{columns}"
    end
  end

  class DuplicateIds < ServiceError
    status 400
    code 'CSV.DuplicateIds'

    attr_reader :ids

    def initialize(ids)
      @ids = ids
      super()
    end

    def detail
      "Multiple rows with the same id are not allowed: #{ids}"
    end

    def meta
      { ids: }
    end
  end

  class MissingIdColumn < ServiceError
    status 400
    code 'CSV.MissingIdColumn'
    detail 'The uploaded CSV is missing the mandatory id column'
  end

  class ForcedColumnBlank < ColumnsError
    status 400
    code 'CSV.ForcedColumnBlank'

    def detail
      "Forced column values may not be blank for columns: #{columns}"
    end
  end

  class ForcedColumnConflict < ServiceError
    status 400
    code 'CSV.ForcedColumnConflict'

    attr_reader :column, :forced_value, :row_value

    def initialize(column, forced_value, row_value)
      @column = column
      @forced_value = forced_value
      @row_value = row_value
      super()
    end

    def detail
      "CSV Row does not match the forced value for column #{column}"
    end

    def meta
      { column:, forced_value:, row_value: }
    end
  end

  class ColumnSerializeError < ServiceError
    status 500
    code 'CSV.ColumnSerializeError'

    attr_reader :column, :reason

    def initialize(column, reason)
      @column = column
      @reason = reason
      super()
    end

    def detail
      "Format error serializing column '#{column}': #{reason}"
    end

    def meta
      { column:, reason: }
    end
  end

  class ErrorCollection < ViewModel::AbstractErrorCollection
    def status
      causes.inject(0) do |prev, cause|
        cause_status = cause.status

        prev_class  = prev / 100
        cause_class = cause_status / 100

        case
        when prev == cause_status
          cause_status
        when prev_class > cause_class
          # Higher class of error overrides lower
          prev
        when prev_class < cause_class
          cause_status
        else
          # two errors in the same class generalize to X00
          cause_status - (cause_status % 100)
        end
      end
    end
  end

  class InvalidCsv < ErrorCollection
    code 'CSV.Invalid'
    def detail
      "Error(s) saving uploaded CSV: #{cause_details}"
    end
  end

  class InvalidRow < ErrorCollection
    code 'CSV.InvalidRow'

    attr_reader :row

    def initialize(row, causes)
      @row = row
      super(causes)
    end

    def detail
      "Error(s) in row #{row}: #{cause_details}"
    end

    def meta
      { row: }
    end
  end

  class MalformedRow < ServiceError
    status 400
    code 'CSV.MalformedRow'

    attr_reader :row, :cause_detail

    def initialize(row, cause_detail)
      @row = row
      @cause_detail = cause_detail
      super()
    end

    def detail
      "Malformed row #{row}: #{cause_detail}"
    end

    def meta
      { row: }
    end
  end

  class ColumnFormatError < ServiceError
    status 400
    code 'CSV.ColumnFormat'

    attr_reader :column, :reason, :value

    def initialize(column, reason, value)
      @column = column
      @reason = reason
      @value = value
      super()
    end

    def detail
      "Format error writing column '#{column}': #{reason}"
    end

    def meta
      { column:, reason:, value: }
    end
  end

  class RequiredFilterError < ServiceError
    status 400
    code 'CSV.RequiredFilter'
    attr_reader :filter, :unique

    def initialize(filter, unique)
      @filter = filter
      @unique = unique
      super()
    end

    def detail
      "Required #{'unique ' if unique}request filter '#{filter}' missing"
    end

    def meta
      { filter:, unique: }
    end
  end

  class << self
    def inherited(subclass)
      super
      subclass.initialize_as_application_csv
    end

    def initialize_as_application_csv
      column :id, format: ParamSerializers::UUID do
        description { I18n.t('application_csv.id.description') }
      end
    end

    def viewmodel_class
      unless instance_variable_defined?(:@viewmodel_class)
        # try to autodetect the viewmodel based on our name
        match = /(.*)Csv$/.match(self.name)

        unless match
          raise ArgumentError.new("Could not auto-determine ViewModel from CSV name '#{self.name}'")
        end

        viewmodel_name = match[1].singularize + 'View'
        type = viewmodel_name.safe_constantize

        unless type
          raise ArgumentError.new("Could not find auto-determined ViewModel with name '#{viewmodel_name}'")
        end

        self.viewmodel_class = type
      end

      @viewmodel_class
    end

    def model_class
      viewmodel_class.model_class
    end

    def columns
      @columns ||= {}
    end

    def readable_columns
      columns.values.select(&:readable?).map { |c| c.name.to_s }
    end

    def writable_columns
      columns.values.select(&:writable?).map { |c| c.name.to_s }
    end

    # Default columns for reading are all readable non-aggregate columns
    def default_serialize_columns
      columns.values.select { |c| c.readable? && c.aggregates.blank? }.map { |c| c.name.to_s }
    end

    # Default columns for writing are all writable columns
    def template_columns
      writable_columns
    end

    def dynamic_column_sets
      @dynamic_column_sets ||= []
    end

    def crutches
      @crutches ||= {}
    end

    def aggregates
      @aggregates ||= {}
    end

    # Eager includes that are always required for serialization, regardless of column
    def global_eager_includes
      @global_eager_includes ||= DeepPreloader::Spec.new({})
    end

    # Deserialization helpers

    # Used to set a reference to a nested referenced entity by id. If the
    # association target has already been set, assert that it is to the
    # same target.
    def set_existing_referenced_child(update_data, association_name, child_viewmodel:, child_id:, references:)
      association_name = association_name.to_s

      if update_data.has_key?(association_name)
        update = references[update_data[association_name][ViewModel::REFERENCE_ATTRIBUTE]]

        unless update
          raise InternalError.new("Invalid CSV deserialization: no existing '#{association_name}'")
        end

        matches = update[ViewModel::TYPE_ATTRIBUTE] == child_viewmodel.view_name &&
                  update[ViewModel::ID_ATTRIBUTE] == child_id &&
                  update[ViewModel::NEW_ATTRIBUTE] == false

        unless matches
          raise InternalError.new(
                  "Invalid CSV deserialization: existing #{association_name} not of expected type " \
                  "#{child_viewmodel.view_name}")
        end

        return
      end

      ref = ViewModel::Reference.new(child_viewmodel, child_id).stable_reference
      update_data[association_name] = { ViewModel::REFERENCE_ATTRIBUTE => ref }
      references[ref] = {
        ViewModel::TYPE_ATTRIBUTE => child_viewmodel.view_name,
        ViewModel::ID_ATTRIBUTE   => child_id,
        ViewModel::NEW_ATTRIBUTE  => false,
      }
    end

    # Used by attribute deserializers for nested referenced entities. Requires a
    # current id for existing children, which must be computed using a crutch.
    # If the association target has already been set differently by another
    # column (e.g. by an explicit foo_id column), simply return the existing value.
    def add_referenced_child_update_data(update_data, association_name, child_viewmodel:, current_child_id:, references:)
      association_name = association_name.to_s
      if (ref = update_data.dig(association_name, ViewModel::REFERENCE_ATTRIBUTE))
        references[ref]
      else
        if current_child_id
          ref = ViewModel::Reference.new(child_viewmodel, current_child_id).stable_reference
          update = {
            ViewModel::TYPE_ATTRIBUTE => child_viewmodel.view_name,
            ViewModel::NEW_ATTRIBUTE  => false,
            ViewModel::ID_ATTRIBUTE   => current_child_id,
          }
        else
          # CSVs deserialize one row at a time, so references only need to be
          # unique within the row
          ref = "ref:s:new_child:#{association_name}"
          update = {
            ViewModel::TYPE_ATTRIBUTE => child_viewmodel.view_name,
            ViewModel::NEW_ATTRIBUTE  => true,
          }
        end

        update_data[association_name] = { ViewModel::REFERENCE_ATTRIBUTE => ref }
        references[ref] = update
        update
      end
    end

    protected

    def viewmodel_class=(type)
      if instance_variable_defined?(:@viewmodel_class)
        raise ArgumentError.new("ViewModel class for CSV '#{self.name}' already set")
      end

      unless type < ViewModel::Record
        raise ArgumentError.new("'#{type.inspect}' is not a valid ViewModel")
      end

      @viewmodel_class = type
    end

    def template_columns=(column_names)
      valid_names = columns.keys

      unless (invalid_names = valid_names - column_names).empty?
        raise ArgumentError.new("Not defined columns: #{invalid_names}")
      end

      unless (invalid_names = writable_columns - column_names).empty?
        raise ArgumentError.new("Not writable columns: #{invalid_names}")
      end

      define_singleton_method(:template_columns) { column_names }
    end

    def column(name, **args, &)
      raise ArgumentError.new("Column #{name} already defined") if columns.has_key?(name.to_s)

      columns[name.to_s] = CsvColumn.build!(name:, **args, &)
    end

    def dynamic_columns(name, **args, &)
      raise ArgumentError.new("Dynamic columns #{name} already defined") if dynamic_column_sets.any? { |dc| dc.name == name }

      dynamic_column_sets << DynamicCsvColumns.build!(name:, **args, &)
    end

    def crutch(name, &block)
      crutches[name] = block
    end

    def aggregate(agg_class)
      aggregates << agg_class
    end

    def global_eager_include(spec)
      spec = DeepPreloader::Spec.parse(spec)
      global_eager_includes.merge!(spec)
    end
  end

  delegate :viewmodel_class, :model_class, to: :class

  BATCH_SIZE = 10000

  def default_serialize_columns(request_filters:)
    column_names = Set.new(self.class.default_serialize_columns)

    self.class.dynamic_column_sets.each do |dc|
      column_names.merge(dc.column_names(request_filters))
    end

    column_names.to_a
  end

  def default_template_columns(request_filters:)
    column_names = Set.new(self.class.template_columns)

    self.class.dynamic_column_sets.each do |dc|
      column_names.merge(dc.column_names(request_filters))
    end

    column_names.to_a
  end

  def serialize_template(column_names, encoding: Encoding::UTF_8, request_filters:, language:)
    i18n_scope = self.class.name.underscore.split('/')

    columns = pick_columns(column_names, request_filters:)
    assert_writable(columns)

    descriptions = I18n.with_locale(language.code) do
      columns.to_h { |c| [c.name, c.template_description(i18n_scope)] }
    end

    examples = I18n.with_locale(language.code) do
      columns.to_h { |c| [c.name, c.template_example(i18n_scope)] }
    end

    to_csv_file(column_names, encoding:) do |csv|
      if descriptions.any? { |name, description| name != :id && description }
        description_row = columns.map { |c| "# #{descriptions[c.name]}" }
        csv << description_row
      end

      if examples.any? { |name, example| name != :id && example }
        example_row = columns.map { |c| "# #{examples[c.name]}" }
        csv << example_row
      end
    end
  end

  def serialize(scope, column_names, request_filters:, lock: nil, limit:, timezone:, encoding: Encoding::UTF_8, aggregate_range: nil, serialize_context:)
    set_context_timezone(timezone, serialize_context)

    columns = pick_columns(column_names, request_filters:)
    assert_readable(columns)

    aggregates = construct_aggregates(columns, aggregate_range:)
    crutch_names = columns.flat_map(&:serialization_crutches).uniq
    eager_includes = construct_eager_includes(columns)

    rows = 0
    truncated = false

    result = to_csv_file(column_names, encoding:) do |csv|
      viewmodel_class.transaction do
        scope = scope.limit(limit + 1) if limit
        scope = scope.lock(lock) if lock

        scope.find_in_batches(batch_size: BATCH_SIZE) do |models|
          DeepPreloader.preload(models, eager_includes, lock:)
          views = models.map { |m| viewmodel_class.new(m) }

          batch_aggregates = calculate_aggregates(aggregates, models, aggregate_range)
          crutches = load_crutches(crutch_names, ids: models.map(&:id), request_filters:, context: serialize_context)

          views.each do |view|
            if limit && rows >= limit
              truncated = true
              next
            end

            rows += 1
            row_crutches = crutches.transform_values { |c| c[view.id] }
            serialize_row(csv, view, columns:, aggregates: batch_aggregates, crutches: row_crutches, serialize_context:)
          end
        end
      end
    end

    [result, rows, truncated]
  end

  # used to serialize the results of deserialization
  def serialize_viewmodels(viewmodels, column_names, request_filters:, lock: nil, timezone:, aggregate_range: nil, encoding: Encoding::UTF_8, serialize_context:)
    set_context_timezone(timezone, serialize_context)

    columns = pick_columns(column_names, request_filters:)
    assert_readable(columns)

    models = viewmodels.map(&:model)

    aggregates = construct_aggregates(columns, aggregate_range:)
    batch_aggregates = calculate_aggregates(aggregates, models, aggregate_range)

    crutch_names = columns.flat_map(&:serialization_crutches).uniq
    crutches = load_crutches(crutch_names, ids: viewmodels.map(&:id), request_filters:, context: serialize_context)

    eager_includes = construct_eager_includes(columns)

    to_csv_file(column_names, encoding:) do |csv|
      viewmodel_class.transaction do
        DeepPreloader.preload(viewmodels.map(&:model), eager_includes, lock:)
        viewmodels.each do |view|
          row_crutches = crutches.transform_values { |c| c[view.id] }
          serialize_row(csv, view, columns:, aggregates: batch_aggregates, crutches: row_crutches, serialize_context:)
        end
      end
    end
  end

  # Certain values in (non-id) CSV columns have a special meaning. In
  # particular, an empty or blank string means "do nothing", while the literal
  # string "remove_value" means to nullify the value. There is presently no way
  # to specify a literal empty/blank string.
  NULLIFY_PLACEHOLDER = 'remove_value'

  def deserialize(csvfile, forced_columns: {}, request_filters:, timezone:, deserialize_context:)
    set_context_timezone(timezone, deserialize_context)
    forced_columns = forced_columns.stringify_keys

    if (blank_forced_columns = forced_columns.select { |_, v| v.blank? }.keys).present?
      raise ForcedColumnBlank.new(blank_forced_columns)
    end

    viewmodel_class.transaction do
      # Load columns
      column_names = read_csv_headers(csvfile)

      if (duplicate_columns = duplicates(column_names)).present?
        raise DuplicateColumns.new(duplicate_columns)
      end

      column_names = (column_names + forced_columns.keys).uniq

      unless column_names.delete('id')
        raise MissingIdColumn.new
      end

      # Columns should be deserialized in the order they are defined in the CSV class
      columns = pick_columns(column_names, request_filters:, in_defined_order: true)
      assert_writable(columns)

      # We want to return any readable columns, in the order supplied (except
      # for id), to allow callers to return the deserialized results with
      # matching columns.
      readable_column_names = ['id', *column_names]
      readable_column_names.delete_if do |name|
        columns.any? { |c| c.name.to_s == name && c.write_only? }
      end

      # Compute crutches
      specified_ids = load_csv_ids(csvfile)

      if (duplicate_ids = duplicates(specified_ids)).present?
        raise DuplicateIds.new(duplicate_ids)
      end

      crutch_names = columns.flat_map(&:deserialization_crutches).uniq
      crutches = load_crutches(crutch_names, ids: specified_ids, request_filters:, context: deserialize_context)

      results = []
      errors = []

      begin
        csv = CSV.new(csvfile, headers: true, row_sep: :auto, skip_lines: /^"?#/)

        csv.each.with_index do |row, row_number|
          id = parse_row_id(row)
          row_crutches = crutches.transform_values { |c| c[id] }

          data, col_errors = construct_update_data(id, row, columns:, row_crutches:, forced_columns:, deserialize_context:)

          if col_errors.present?
            error = InvalidRow.new(row_number + 1, col_errors)
            errors << error
          else
            begin
              Rails.logger.debug { "Deserializing row from CSV: #{data}" }
              # Each individual row may be rolled back, so that we can collect errors for the whole document
              result = ApplicationRecord.transaction(requires_new: true) do
                update_data, references = data.fetch_values(:data, :references)
                deserialize_row(update_data, references:, deserialize_context:)
              end

              # Similarly to VM controller methods, allow a block to inspect and
              # modify the deserialized view before returning. Views are
              # supplied individually to isolate errors to their row.
              if block_given?
                result = yield(result)
              end

              results << result
            rescue ViewModel::DeserializationError::Collection => e
              # Re-wrap error collections as invalid rows
              error = InvalidRow.new(row_number + 1, e.causes)
              errors << error
            rescue ViewModel::DeserializationError, ServiceError, ServiceErrorWithBlame => e
              error = InvalidRow.new(row_number + 1, e)
              errors << error
            end
          end
        end
      rescue CSV::MalformedCSVError => e
        # CSV iteration is stopped once a malformed line is encountered, but we
        # can still report other errors prior to this
        row_error = MalformedRow.new(e.line_number, e.message)
        errors << row_error
      end

      if errors.present?
        bundled_error = InvalidCsv.new(errors)
        raise bundled_error
      end

      [results, readable_column_names]
    end
  end

  private

  def pick_columns(column_names, request_filters:, in_defined_order: false)
    dynamic_columns = {}

    self.class.dynamic_column_sets.each do |dc|
      cols = dc.columns(request_filters)
      dynamic_columns.merge!(cols)
    end

    invalid_column_names = []

    columns = column_names.map do |n|
      if self.class.columns.has_key?(n)
        self.class.columns[n]
      elsif dynamic_columns.has_key?(n)
        dynamic_columns[n]
      else
        invalid_column_names << n
      end
    end

    unless invalid_column_names.empty?
      valid_column_names = self.class.columns.keys + dynamic_columns.keys
      raise InvalidColumns.new(invalid_column_names, valid_column_names)
    end

    if in_defined_order
      column_names = self.class.columns.keys + dynamic_columns.keys
      column_indexes = column_names.each_with_index.to_h
      columns.sort_by! { |c| column_indexes[c.name.to_s] }
    end

    columns
  end

  def assert_writable(columns)
    if (read_only_columns = columns.select(&:read_only?)).present?
      raise ReadOnlyColumns.new(read_only_columns.map(&:name))
    end
  end

  def assert_readable(columns)
    if (write_only_columns = columns.select(&:write_only?)).present?
      raise WriteOnlyColumns.new(write_only_columns.map(&:name))
    end
  end

  def construct_eager_includes(columns)
    eager_includes = DeepPreloader::Spec.new
    eager_includes.merge!(self.class.global_eager_includes)
    columns.each { |col| eager_includes.merge!(col.eager_includes) }
    eager_includes
  end

  def construct_aggregates(columns, aggregate_range:)
    aggregate_columns = columns.reject { |c| c.aggregates.empty? }

    range_aggregate_columns = aggregate_columns.select do |col|
      col.aggregates.any?(&:requires_range?)
    end

    if range_aggregate_columns.present? && aggregate_range.nil?
      raise MissingAggregateRange.new(range_aggregate_columns.map(&:name))
    end

    aggregate_columns.flat_map(&:aggregates).uniq
  end

  def calculate_aggregates(aggregates, models, aggregate_range)
    aggregates.index_with do |aggregate|
      if aggregate.is_a?(Class) && aggregate < Aggregates::ApplicationAggregate
        # Structured query based ApplicationAggregate
        agg_scope, agg_key = aggregate.scope_for(model_class)
        agg_scope = agg_scope.where(agg_key => models.map(&:id))
        aggregate.calculate_aggregates(agg_key, agg_scope, aggregate_range)
      else
        # Arbitrary aggregator, e.g. passing the models to a service
        aggregate.calculate_aggregates(models, aggregate_range)
      end
    end
  end

  def to_csv_file(column_names, encoding: Encoding::UTF_8)
    encoding = Encoding.find(encoding)

    if encoding == Encoding::UTF_8
      tempfile = Tempfile.new('csv-data')
      tempfile.write("\uFEFF") # Add a UTF-8 BOM to the CSV, to better support Excel
    else
      tempfile = Tempfile.new('csv-data', encoding:, undef: :replace)
    end

    tempfile.unlink

    csv = CSV.new(tempfile.to_io, headers: column_names, write_headers: true, row_sep: "\r\n")
    yield(csv) if block_given?
    tempfile.rewind
    tempfile
  end

  def serialize_row(csv, view, columns:, aggregates:, crutches:, serialize_context:)
    # TODO: This means that only access to the root will be access
    # controlled, which is similar to the guarantees offered by cached
    # view serialization. We could do better, if we provide more first
    # class support for association paths in column definitions, and
    # wrapped the path navigation with wrap_serialize and
    # context.for_child.
    ViewModel::Callbacks.wrap_serialize(view, context: serialize_context) do
      row = columns.map do |column|
        column.serialize(view, aggregates:, crutches:, serialize_context:)
      rescue ParamSerializers::DumpError => e
        raise ColumnSerializeError.new(column.name, e.message)
      end

      csv << row
    end
  end

  def deserialize_row(update_data, references:, deserialize_context:)
    viewmodel_class.deserialize_from_view(update_data, references:, deserialize_context:)
  end

  def read_csv_headers(csvfile)
    save_excursion(csvfile) do
      csv = CSV.new(csvfile, headers: true, row_sep: :auto, return_headers: true)
      row = csv.shift
      raise CsvEmpty.new if row.blank?

      row.headers
    rescue CSV::MalformedCSVError => e
      row_error = MalformedRow.new(e.line_number, e.message)
      raise InvalidCsv.new(row_error)
    end
  end

  def each_csv_row(csvfile, &)
    save_excursion(csvfile) do
      csv = CSV.new(csvfile, headers: true, row_sep: :auto)
      csv.each(&)
    rescue CSV::MalformedCSVError => e
      row_error = MalformedRow.new(e.line_number, e.message)
      raise InvalidCsv.new(row_error)
    end
  end

  def save_excursion(stream)
    pos = stream.pos
    yield(stream)
  ensure
    stream.seek(pos, IO::SEEK_SET)
  end

  def load_csv_ids(csvfile)
    ids = []

    each_csv_row(csvfile) do |row|
      id = row['id']
      ids << id if id
    end

    ids
  end

  CrutchEnv = Value.new(:request_filters, :context) do
    def request_context
      context.request_context
    end
  end

  def load_crutches(crutch_names, ids:, request_filters:, context:)
    env = CrutchEnv.with(request_filters:, context:)
    crutch_names.index_with do |name|
      crutch_fn = self.class.crutches.fetch(name) do
        raise InternalError.new("No crutch defined with name #{name}")
      end
      env.instance_exec(ids, &crutch_fn)
    end
  end

  def parse_row_id(csv_row)
    id = csv_row['id']
    if id.blank?
      nil
    else
      ParamSerializers::UUID.load(id)
    end
  rescue ParamSerializers::LoadError => e
    raise ColumnFormatError.new('id', e.message, id)
  end

  def construct_update_data(id, csv_row, columns:, row_crutches:, forced_columns:, deserialize_context:)
    new = id.nil?

    references = {}
    update_data = {
      ViewModel::TYPE_ATTRIBUTE  => viewmodel_class.view_name,
      ViewModel::NEW_ATTRIBUTE   => new,
    }

    update_data[ViewModel::ID_ATTRIBUTE] = id unless new

    row_errors = []
    columns.each do |column|
      column_name = column.name.to_s

      if forced_columns.has_key?(column_name)
        raw_value = forced_columns[column_name]

        # The CSV must either not assert the forced column or assert the same value
        if csv_row.has_key?(column_name)
          row_value = csv_row[column_name]
          unless row_value == '' || row_value == raw_value
            raise ForcedColumnConflict.new(column_name, raw_value, row_value)
          end
        end
      else
        raw_value = csv_row.fetch(column_name)
      end

      if raw_value.blank?
        # A blank value when editing indicates no change, and when creating
        # indicates the default value (which may be overridden by the column
        # definition, or may come from the viewmodel)
        next unless id.nil? && column.has_default?

        raw_value = column.default
      elsif raw_value == NULLIFY_PLACEHOLDER
        raw_value = nil
      end

      column.deserialize(
        raw_value, update_data,
        row_id: id, crutches: row_crutches, viewmodel_class: self.class.viewmodel_class, references:, deserialize_context:)

    rescue ColumnFormatError => e
      row_errors << e
    rescue ParamSerializers::LoadError => e
      wrapped_error =
        begin
          raise ColumnFormatError.new(column.name, e.message, raw_value)
        rescue ColumnFormatError => e
          e
        end

      row_errors << wrapped_error
    rescue ParamSerializers::DumpError => e
      wrapped_error =
        begin
          raise ColumnSerializeError.new(column.name, e.message)
        rescue ColumnSerializeError => e
          e
        end

      row_errors << wrapped_error
    end

    if row_errors.present?
      return nil, row_errors
    else
      data = { data: update_data, references: }
      return data, nil
    end
  end

  def duplicates(enumerable)
    counts = enumerable.each_with_object(Hash.new(0)) do |elt, h|
      h[elt] += 1
    end

    counts.each_with_object([]) do |(elt, count), result|
      result << elt if count > 1
    end
  end

  def set_context_timezone(timezone, context)
    context.add_view_context_data(ParamSerializers::TimeInZone, timezone, indexed: false)
  end

  def new_view
    viewmodel_class.for_new_model
  end
end
