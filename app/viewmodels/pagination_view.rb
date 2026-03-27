# frozen_string_literal: true

class PaginationView < ViewModel::Record
  self.model_class = Page
  self.schema_version = 1

  attributes :start, :page_size, :order, :direction, :last_page, :total_count
  attr_reader :last_page, :total_count

  def initialize(model, last_page:, total_count:)
    super(model)
    @last_page = last_page
    @total_count = total_count
  end

  delegate :size_limit?, to: :model

  def order
    model.name
  end

  include ViewmodelMigrationHelpers
end
