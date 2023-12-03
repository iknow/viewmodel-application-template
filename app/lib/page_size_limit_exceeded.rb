# frozen_string_literal: true

class PageSizeLimitExceeded < ViewModel::AbstractError
  status 400
  code 'Request.PageSizeLimit'

  def initialize(page_size, limit)
    @page_size = page_size
    @limit = limit
    super()
  end

  def detail
    "Requested page size #{@page_size} exceeds the limit for this API of #{@limit}"
  end

  def meta
    {
      page_size: @page_size,
      limit: @limit,
    }
  end
end
