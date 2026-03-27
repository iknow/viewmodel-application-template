# frozen_string_literal: true

class BlockedEmailDomainsIndex < Chewy::Index
  include ApplicationIndex
  model BlockedEmailDomain
  view Search::BlockedEmailDomainView

  define_raw_mapping do
    {
      dynamic: false,
      properties: {
        id:   { type: 'keyword' },
        name: { type: 'text', analyzer: 'simple', fields: { raw: { type: 'keyword' } } },
      },
    }
  end

  index_scope

  view_root do |_user, view, _crutches|
    view
  end
end
