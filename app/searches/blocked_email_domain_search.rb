# frozen_string_literal: true

class BlockedEmailDomainSearch < ChewyIndexedSearch
  index BlockedEmailDomainsIndex

  def query_string_fields
    @query_string_fields ||= ['name', 'name.raw']
  end
end
