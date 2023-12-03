# frozen_string_literal: true

class Api::UsersController < Api::ViewModelController
  self.viewmodel_class = UserView
  self.access_control = UserAccessControl
end
