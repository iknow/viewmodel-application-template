# frozen_string_literal: true

class PaginationView < ViewModel::Record
  self.model_class = Page

  attributes :start, :page_size, :order, :direction, :last_page
  attr_reader :last_page

  def initialize(model, last_page:)
    super(model)
    @last_page = last_page
  end

  delegate :size_limit?, to: :model

  def order
    model.name
  end
end
