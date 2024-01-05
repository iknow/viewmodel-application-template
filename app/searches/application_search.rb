# frozen_string_literal: true

class ApplicationSearch
  # How many results are permitted for an unpaginated search query
  MAX_UNPAGINATED_RESULTS = 100

  class << self
    def uses_scope_filters?
      false
    end
  end
end
