# frozen_string_literal: true

module Schemas
  class CsvResultView < SchemaBaseView
    def url_type = 'string'
    def url_nullable = false
    def rows_type = 'integer'
    def rows_nullable = false
    def truncated_type = 'boolean'
    def truncated_nullable = false
  end
end
