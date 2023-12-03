# frozen_string_literal: true

class UserAccessControl < ApplicationAccessControl
  view UserView.view_name do
    visible_if!('has viewUsers ability') do
      context.permissions.includes_ability?(Ability::VIEW_USERS)
    end

    visible_if!('self-viewing') do
      context.resource_owner == model
    end

    visible_if!('creating or created a new user') do
      view.new_model? || view.model.previously_new_record?
    end

    editable_if!('has editUsers ability') do
      context.permissions.includes_ability?(Ability::EDIT_USERS)
    end

    edit_valid_if!('creating a new user') do
      changes.new?
    end
  end
end
