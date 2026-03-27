# frozen_string_literal: true

module CsvHelper
  extend ActiveSupport::Concern
  included do
    # construct a FilterSet corresponding to controller request filters
    let(:filter_params) { {} }
    let(:available_filters) { controller.available_filters }

    let(:controller) do
      "Api::#{described_class.model_class.name.pluralize}Controller".constantize
    end

    let(:request_filters) do
      parsed_filters = available_filters.new_filter_values

      filter_params.each do |key, value|
        parsed_filters[key] = value
      end

      # apply defaults
      available_filters.each_filter do |filter|
        if !parsed_filters.include?(filter.name) && filter.default?
          parsed_filters[filter.name] = filter.default_value(parsed_filters)
        end
      end

      parsed_filters
    end

    let(:forced_columns) { {} }

    let(:scope) { described_class.model_class.all }
    let(:lock) { nil }
    let(:limit) { nil }
    let(:timezone) { ParamSerializers::Timezone.load('Asia/Tokyo') }
    let(:aggregate_range) { nil }
    let(:expected_truncated) { false }

    let(:column_names) { column_expectations.keys.map(&:to_s) }
    let(:column_expectations) { {} }
  end

  # Serialize helpers rely on subject column_expectations, which are a hash of
  # expected serialized CSV values in the row corresponding to `subject`
  def serialize
    result_file, row_count, truncated =
      subject.serialize(
        merge_scopes(scope, request_filters.scope),
        column_names,
        request_filters:, lock:, limit:, timezone:, aggregate_range:, serialize_context: vm_serialize_context)

    # The result file should begin with a UTF-8 BOM. Read (and thereby remove)
    # this, and verify it's valid.
    consume_bom!(result_file)

    return result_file, row_count, truncated
  end

  def consume_bom!(stream)
    consumed_bom = stream.read(3)
    expected_bom = (+"\uFEFF").force_encoding('ascii-8bit')
    expect(consumed_bom).to eq(expected_bom)
  end

  def consume_string_bom!(string)
    result = string.delete_prefix!("\uFEFF")
    expect(result).not_to be_nil
  end

  def merge_scopes(*scopes)
    scopes.inject do |a, b|
      case
      when b.nil?
        a
      when a.nil?
        b
      else
        a.merge(b)
      end
    end
  end

  RSpec.shared_examples 'serializes the column expectations' do
    it 'serializes the column expectations' do
      result_file, row_count, truncated = serialize
      table = CSV.new(result_file.to_io, headers: true).read
      expect(table.headers).to eq(column_names)

      expect(row_count).to eq(1)
      expect(table.size).to eq(row_count)
      expect(truncated).to eq(expected_truncated)

      row = table[0]

      column_expectations.each do |column, expected_value|
        expect(row[column.to_s]).to eq(expected_value), "for column '#{column}' expected #{expected_value.inspect}, got #{row[column.to_s].inspect}"
      end
    end
  end

  def vm_serialize_context(**args)
    super(described_class.viewmodel_class, **args)
  end

  def vm_deserialize_context(**args)
    super(described_class.viewmodel_class, **args)
  end

  def csv_time(t)
    if t.nil?
      ''
    else
      ParamSerializers::TimeInZone.new(timezone).dump(t, json: false)
    end
  end

  def dump_to_csv(hashes)
    hashes = Array.wrap(hashes)
    csvfile = Tempfile.new
    csvfile.unlink

    expect(hashes).to be_present
    headers = hashes.first.keys

    csv = CSV.new(csvfile.to_io, headers:, write_headers: true)

    hashes.each do |hash|
      expect(hash.keys).to eq(headers)
      csv << hash.values
    end

    csvfile.rewind
    csvfile
  end

  # deserialize helpers expect a `request_columns`, which like
  # column_expectations is a hash representing a single row of csv-formatted
  # columns.
  def deserialize_csv
    csvfile = dump_to_csv(request_columns)
    subject.deserialize(csvfile, forced_columns:, request_filters:, timezone:, deserialize_context: vm_deserialize_context)
  end

  def deserialize_update
    results, result_columns = deserialize_csv

    expect(result_columns).to eq(request_columns.keys.map(&:to_s))
    expect(results.length).to eq(1)

    result = results.first.model
    expect(result).to be_kind_of(described_class.model_class) & have_attributes(id: request_columns[:id])
    expect(result).to be_persisted
    result
  end

  def match_a_row_error(row, *containing)
    have_attributes(
      causes: contain_exactly(
        be_kind_of(ApplicationCsv::InvalidRow) &
        have_attributes(row:, causes: contain_exactly(*containing))))
  end

  RSpec.shared_examples 'updates the column' do |column, serialized_value|
    let(:request_columns) { super().merge(column => serialized_value) }

    it 'makes the update' do
      result = deserialize_update
      expect(result.send(column)).to column_expectation
      other_expectations(result)
    end

    let(:column_expectation) do
      eq(serialized_value)
    end

    def other_expectations(_result)
      true
    end
  end

  RSpec.shared_examples 'with stubbed csv upload' do
    let(:stub_url) { 'https://example.com/some_resource.csv' }

    before do
      expect_any_instance_of(CsvRendering).to receive(:upload_csv_file) do |_controller, file|
        consume_bom!(file)
        csv = CSV.new(file.to_io, headers: true).read
        rows = csv.map(&:to_h)
        expect(rows.size).to eq(expected_count)
        expect(rows).to expected_rows
        stub_url
      end
    end
  end

  # Requires expected_count, expected_rows and expected_truncated
  RSpec.shared_examples 'responds successfully with CSV result' do
    include_examples 'with stubbed csv upload'

    let(:expected_result) do
      be_a_viewmodel_response_of(CsvResultView, id: nil, rows: expected_count, truncated: expected_truncated, url: stub_url)
    end

    include_examples 'responds successfully with result'
  end
end
