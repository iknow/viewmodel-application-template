# frozen_string_literal: true

class PageSizeLimitExceeded < ViewModel::AbstractError
  status 400
  code 'Request.PageSizeLimit'

  def initialize(page_size, limit, background:)
    @page_size = page_size
    @limit = limit
    @background = background
    super()
  end

  def detail
    type = @background ? 'background' : 'foreground'
    "Requested page size #{@page_size} exceeds the #{type} limit for this API of #{@limit}"
  end

  def meta
    {
      page_size: @page_size,
      limit: @limit,
      background: @background,
    }
  end
end
