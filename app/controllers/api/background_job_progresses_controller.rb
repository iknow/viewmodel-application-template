# frozen_string_literal: true

class Api::BackgroundJobProgressesController < Api::ViewModelController
  self.viewmodel_class = BackgroundJobProgressView
  self.access_control = ViewModel::AccessControl::ReadOnly

  # Presently, background jobs are accessed only by their secret uuid.
  undef_method :index
  undef_method :create
  undef_method :destroy
end
