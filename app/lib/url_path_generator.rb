# frozen_string_literal: true

class UrlPathGenerator
  class << self
    TEMPLATE_REGEX = /:(\w+)/

    def build(path_base, query_params, url_params)
      required_params = list_params(path_base)

      if (missing = (required_params - url_params.keys)).present?
        raise ArgumentError.new("URL template missing required parameters: #{missing}")
      end

      if (extra = (url_params.keys - required_params)).present?
        raise ArgumentError.new("Unknown parameters provided to URL template: #{extra}")
      end

      path = path_base.gsub(TEMPLATE_REGEX) do |_match|
        escape_uri_segment(url_params[Regexp.last_match(1).to_sym])
      end

      path << query_string(query_params)
      path
    end

    def list_params(path_base)
      path_base.scan(TEMPLATE_REGEX).map { |captures| captures.first.to_sym }
    end

    private

    def query_string(params)
      return '' if params.empty?
      "?#{escape_query_parameters(params)}"
    end

    # We opt for CGI escaping here to prevent URL parametes with
    # slashes from persisting, as that has semantic meaning that could
    # push down into a nested route.
    def escape_uri_segment(segment)
      CGI.escape(segment)
    end

    def escape_query_parameters(params)
      params.map { |name, param| "#{name}=#{CGI.escape(param.to_s)}" }.join('&')
    end
  end
end
