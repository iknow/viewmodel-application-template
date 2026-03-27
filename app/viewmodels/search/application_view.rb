# frozen_string_literal: true

class Search::ApplicationView < ViewModel
  include SearchRangeFormatting

  def preloadable_dependencies(include_referenced: true)
    [self]
  end
end
