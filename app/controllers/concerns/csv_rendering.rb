# frozen_string_literal: true

module CsvRendering
  extend ActiveSupport::Concern

  included do
    backgroundable_action :csv_index, :csv_update
  end

  class_methods do
    attr_writer :csv_class

    def csv_class
      unless instance_variable_defined?(:@csv_class)
        raise ArgumentError.new("CSV class not defined for controller '#{self.name}'")
      end

      @csv_class
    end
  end

  delegate :csv_class, to: :class

  CSV_LIMIT = 100000

  def authorize_csv_download!
    authorize_ability!(Ability::DOWNLOAD_CSV)
  end

  def new_csv
    csv_class.new
  end

  def csv_template
    csv = new_csv

    columns = parse_array_param(:columns, default: nil)
    columns ||= csv.default_template_columns(request_filters: current_filters)
    encoding = parse_param(:encoding, with: ParamSerializers::Encoding, default: Encoding::UTF_8)
    language = parse_param(:csv_language, with: ParamSerializers::Language, default: Language::EN)

    csv_file = csv.serialize_template(columns, encoding:, request_filters: current_filters, language:)
    filename = "#{viewmodel_class.view_name.underscore}_template.csv"
    send_data(csv_file.read, { type: 'text/csv', filename: })
  end

  def csv_index(scope: viewmodel_class.model_class.all, lock: nil, serialize_context: new_serialize_context(viewmodel_class:))
    unless csv_class.viewmodel_class == viewmodel_class
      raise ViewModel::Error.new(status: 400, detail: "Cannot render #{csv_class.name} for viewmodel #{viewmodel_class.name}")
    end

    authorize_csv_download!

    csv = new_csv
    column_names = parse_array_param(:columns, default: csv.default_serialize_columns(request_filters: current_filters))
    timezone = parse_param(:timezone, with: ParamSerializers::Timezone)
    aggregate_range = parse_param(:aggregate_range, with: ParamSerializers::ExclusiveTimeRange, default: nil)
    encoding = parse_param(:encoding, with: ParamSerializers::Encoding, default: Encoding::UTF_8)
    limit = [current_page&.page_size, CSV_LIMIT].compact.min
    scope = merge_scopes(scope, current_filters.scope)

    csv_file, rows, truncated = csv.serialize(
      scope, column_names, request_filters: current_filters, encoding:, limit:, lock:, timezone:, aggregate_range:, serialize_context:)

    filename = "#{viewmodel_class.view_name.underscore}_#{Time.now.utc.strftime('%Y%m%d%H%M%S')}.csv"
    url = upload_csv_file(csv_file, filename)

    yield if block_given?

    result = CsvResultView.new(url:, rows:, truncated:)
    render_viewmodel(result, serialize_context: CsvResultView.new_serialize_context)
  end

  def csv_update(serialize_context: new_serialize_context(viewmodel_class:),
                 deserialize_context: new_deserialize_context(viewmodel_class:, allow_remote_upload: true))
    uploaded_file = parse_param(:csv, with: ParamSerializers::UploadedFile)

    # The encoding of Rack's upload tempfile is ASCII_8BIT. We expect CSVs to be
    # Unicode: optionally with a BOM specified, assuming UTF-8 if no BOM is
    # present. Regardless of the external encoding, we want to ensure that the
    # internal_encoding is utf-8. This has to be done via reopen, because
    # `set_encoding_by_bom` empirically selects the wrong encoding when called
    # on Rack's tempfile.
    uploaded_csv = File.open(uploaded_file.tempfile.path, 'rb:bom|utf-8:utf-8')

    timezone = parse_param(:timezone, with: ParamSerializers::Timezone)
    forced_columns = parse_param(
      :forced_columns,
      with: ParamSerializers::HashOf.new(ParamSerializers::String, ParamSerializers::String),
      default: {})

    authorize_csv_download!

    prerendered = ApplicationRecord.transaction do
      csv = new_csv
      viewmodels, column_names =
        csv.deserialize(uploaded_csv,
                        forced_columns:, request_filters: current_filters, timezone:, deserialize_context:)

      csv_file = csv.serialize_viewmodels(
        viewmodels, column_names, request_filters: current_filters, timezone:, serialize_context:)

      filename = "#{viewmodel_class.view_name.underscore}_upload_#{Time.now.utc.strftime('%Y%m%d%H%M%S')}.csv"
      url = upload_csv_file(csv_file, filename)
      result = CsvResultView.new(url:, rows: viewmodels.size, truncated: false)
      prerender_viewmodel(result, serialize_context: CsvResultView.new_serialize_context)
    end

    render_json_string(prerendered)
  end

  private

  def upload_csv_file(csv_file, download_filename)
    disposition = ActionDispatch::Http::ContentDisposition.format(disposition: 'attachment', filename: download_filename)
    S3Client.upload_to_inbox(csv_file, content_type: 'text/csv', options: { content_disposition: disposition })
  end
end
