# frozen_string_literal: true

class Api::BlockedEmailDomainsController < Api::ViewModelController
  search_with BlockedEmailDomainSearch

  self.access_control = BlockedEmailDomainAccessControl
  self.viewmodel_class = BlockedEmailDomainView

  pagination_order(:name) do
    scope { |dir| BlockedEmailDomain.reorder(name: dir) }
    search nil
  end

  default_pagination_order :name

  before_action -> { authorize_ability!(Ability::EDIT_BLOCKED_EMAIL_DOMAINS) }
end
