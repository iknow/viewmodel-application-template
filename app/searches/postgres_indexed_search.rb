# frozen_string_literal: true

class PostgresIndexedSearch < ApplicationSearch
  class << self
    def uses_scope_filters?
      true
    end
  end

  def initialize(query_string, translation_language: nil, page:, filters:, filter_only: false)
    super()

    if filter_only
      raise ArgumentError.new('filter_only is redundant with PostgresIndexedSearch')
    end

    @supplementary_fields = []
    @translation_languages = [translation_language] if translation_language

    query = build_query(query_string)
    query = filter_query(query, filters)
    query = paginate_query(query, page)
    query = select_fields(query)
    @query = query
  end

  def load_models(lock: nil)
    @load_models ||=
      begin
        scope = query
        scope.lock(lock) if lock
        scope.to_a
      end
  end

  def size
    load_models.size
  end

  # ES offers this, but Postgres doesn't without extra work.
  def total
    nil
  end

  def supplementary_data
    return {} if @supplementary_fields.blank?

    @supplementary_fields.index_with do |field_name|
      load_models.to_h do |model|
        [model.id, model[field_name]]
      end
    end
  end

  # May be called during query building to request that the value of a given
  # column name in the index query be collected for the response's supplementary
  # metadata. This is quite a limited model, because it only allows
  # supplementary data to be literal column names, rather than computed values.
  def record_supplementary_data(field_name)
    @supplementary_fields << field_name.to_s
  end

  def model_class
    raise RuntimeError.new('Abstract method')
  end

  def search_scope
    model_class.all
  end

  def search_expression
    raise RuntimeError.new('Abstract method')
  end

  def build_query(query_string)
    quoted_string = ApplicationRecord.connection.quote(query_string)
    expression = self.search_expression

    search_scope
      .joins("CROSS JOIN websearch_to_tsquery('english', #{quoted_string}) query")
      .where("query @@ #{expression}")
      .select("#{model_class.table_name}.*")
      .select("ts_rank_cd(#{expression}, query) AS ts_rank")
  end

  def filter_query(query, filters)
    return query unless filters

    query.merge(filters.scope)
  end

  def paginate_query(query, page, filters)
    if page
      query.merge(page.scope(filters))
    else
      query.limit(MAX_UNPAGINATED_RESULTS)
    end
  end

  def select_fields(query)
    @supplementary_fields.inject(query) do |q, field|
      quoted = ApplicationRecord.connection.quote_column_name(field)
      q.select(quoted)
    end
  end
end
