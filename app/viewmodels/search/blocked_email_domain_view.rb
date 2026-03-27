# frozen_string_literal: true

class Search::BlockedEmailDomainView < Search::ApplicationView
  attribute :blocked_email_domain
  delegate :id, to: :blocked_email_domain

  def serialize_view(json, serialize_context: nil)
    json.id   blocked_email_domain.id
    json.name blocked_email_domain.name
  end
end
