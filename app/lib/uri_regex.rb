# frozen_string_literal: true

class UriRegex
  DEFAULT_SCHEMES = %w[http https].freeze

  def self.unanchored(schemes = DEFAULT_SCHEMES)
    URI::DEFAULT_PARSER.make_regexp(schemes)
  end

  def self.anchored(schemes = DEFAULT_SCHEMES)
    /\A#{unanchored(schemes)}\z/
  end
end
