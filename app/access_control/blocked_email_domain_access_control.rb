# frozen_string_literal: true

class BlockedEmailDomainAccessControl < ApplicationAccessControl
  view BlockedEmailDomainView.view_name do
    visible_if!('can edit blocked email domains') do
      context.permissions.includes_ability?(Ability::EDIT_BLOCKED_EMAIL_DOMAINS)
    end

    editable_if!('can edit blocked email domains') do
      context.permissions.includes_ability?(Ability::EDIT_BLOCKED_EMAIL_DOMAINS)
    end
  end
end
