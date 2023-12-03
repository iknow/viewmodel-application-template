# frozen_string_literal: true

class ApplicationSearch
  # How many results are permitted for an unpaginated search query
  MAX_UNPAGINATED_RESULTS = 100

  class << self
    attr_accessor :pagination_data

    def inherited(subclass)
      super
      subclass.initialize_as_application_search
    end

    def initialize_as_application_search
      @index_class = nil
    end

    def index(index_class)
      @index_class = index_class
    end

    def index_class
      unless @index_class.is_a?(Class) && @index_class < Chewy::Index
        raise RuntimeError.new("Index for #{self.name} is not set to a Chewy index. Use `index MyIndex` to set on the class.")
      end

      @index_class
    end

    def model_class
      index_class.model_class
    end
  end

  def initialize(query_string, translation_language: nil, page:, filters:, filter_only: false)
    if query_string.present? && filter_only
      raise ArgumentError.new('Query string presented to filter_only query')
    end

    @supplementary_fields = []
    @translation_languages = [translation_language] if translation_language

    query_string = clean_query(query_string) unless filter_only
    index = select_index(filters)
    query = build_query(index, query_string, filter_only:)
    query = filter_query(query, filters)
    query = paginate_query(query, page)
    query = select_fields(query)
    @query = query
  end

  def load_models(lock: nil)
    return [] if query.total.zero?
    @load_models ||=
      begin
        ids = query.map(&:id)

        scope = self.class.model_class
        scope = scope.lock(lock) if lock

        models = scope.where(id: ids)
        models_by_id = models.index_by(&:id)

        ids.map! { |id| models_by_id[id] }.tap(&:compact!)
      end
  end

  # For each result, return the source document returned by ES
  def result_documents
    @result_documents ||=
      query.map { |wrapper| wrapper._data['_source'] }
  end

  def supplementary_data
    return {} if @supplementary_fields.blank?

    @supplementary_fields.index_with do |field_name|
      query.each_with_object({}) do |wrapper, field_data|
        field_data[wrapper.id] = wrapper.attributes[field_name]
      end
    end
  end

  delegate :total, :size, to: :query

  protected

  # May be called during query building to request that the value of a given
  # attribute in the index be collected for the response's supplementary
  # metadata.
  def record_supplementary_data(field_name)
    @supplementary_fields << field_name.to_s
  end

  def query_string_fields
    ['_all']
  end

  def boost_fields(fields, boosts)
    fields.map do |field|
      if (boost = boosts[field.to_s])
        "#{field}^#{boost}"
      else
        field
      end
    end
  end

  private

  attr_reader :query, :translation_languages

  def clean_query(query_string)
    query_string.strip.force_encoding('utf-8').scrub
  end

  def select_index(_filters)
    index_class
  end

  # May be overridden by subclasses to define complex query behaviour.
  def build_query(index, query_string, filter_only:)
    query_string_fields = self.query_string_fields

    if filter_only || query_string.blank? || query_string == '*'
      index.all
    else
      index.query do
        simple_query_string query: query_string, fields: query_string_fields
      end
    end
  end

  def filter_query(query, filters)
    return query unless filters

    filters.search_terms.inject(query) do |q, term|
      q.filter(term)
    end
  end

  def paginate_query(query, page)
    if page
      query = query.order(page.order.search_for(page.direction))
      query = query.limit(page.page_size) if page.page_size > 0
      query = query.offset(page.start)    if page.start > 0
      query
    else
      query.limit(MAX_UNPAGINATED_RESULTS)
    end
  end

  def select_fields(query)
    query.source(includes: [:id, *@supplementary_fields])
  end

  def field_translations(field)
    if translation_languages.nil?
      ["#{field}_translations.*"]
    else
      translation_languages.map do |language|
        "#{field}_translations.#{language.code}"
      end
    end
  end

  def fields_translations(fields)
    fields.flat_map { |field| field_translations(field) }
  end

  # When creating queries, match ApplicationIndex's standard analyzer disabling logic
  def language_fields(language)
    if language.ideographic
      ["text.#{language.code}"]
    else
      ["text.#{language.code}", "text.#{language.code}.standard"]
    end
  end

  delegate :index_class, to: :class
end
