# frozen_string_literal: true

class Api::UsersController < Api::ViewModelController
  self.viewmodel_class = UserView
  self.access_control = UserAccessControl

  include CsvRendering
  self.csv_class = UserCsv

  include SupplementaryAggregates
  add_supplementary_aggregates Aggregates::ExampleAggregates
end
