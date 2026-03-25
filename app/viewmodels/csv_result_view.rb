# frozen_string_literal: true

class CsvResultView < ViewModel::Record
  Model = Struct.new(:url, :rows, :truncated)
  self.model_class = Model
  self.view_name = 'CsvResult'

  attributes :url, :rows, :truncated

  def initialize(...)
    super(Model.new(...))
  end
end
