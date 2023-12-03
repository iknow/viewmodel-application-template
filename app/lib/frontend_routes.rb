# frozen_string_literal: true

class FrontendRoutes
  Route = Struct.new(:path_base, :url_params, :query_params, :required_query_params)
  @routes = {}

  class << self
    def route(name, path_base, query_params: [], required_params: [])
      url_params = UrlPathGenerator.list_params(path_base)

      unless (extra_params = required_params - query_params).empty?
        raise ArgumentError.new("Required query params must exist: #{extra_params}")
      end

      @routes[name] = Route.new(path_base, url_params, query_params, required_params)

      define_method(:"#{name}_path") { |*args, **kwargs| path(name, *args, **kwargs) }
      define_method(:"#{name}_url")  { |*args, **kwargs| url(name, *args, **kwargs) }
    end

    def route_for(name)
      @routes.fetch(name) do
        raise ArgumentError.new("No front-end route defined with name '#{name}'")
      end
    end
  end

  route :dashboard, '/'

  def initialize(base_url)
    uri = (base_url.is_a?(URI) ? base_url : URI.parse(base_url)).normalize
    raise ArgumentError.new('Base URL is not HTTP(S)') unless %w[http https].include?(uri.scheme)

    @base_url = uri.to_s.chomp('/')
  end

  def path(name, *positional_url_params, **query_params)
    route = self.class.route_for(name)

    validate_query_parameters!(query_params,
                               valid: route.query_params,
                               required: route.required_query_params)

    # Convert models to appropriate id for URL param with Rails helper
    positional_url_params = positional_url_params.map(&:to_param)

    unless positional_url_params.size == route.url_params.size
      raise ArgumentError.new(
              "Invalid URL parameters, expected exactly #{route.url_params.size} " \
              "(#{route.url_params.map(&:inspect).join(', ')})")
    end

    url_params = route.url_params.zip(positional_url_params).to_h

    UrlPathGenerator.build(route.path_base, query_params, url_params)
  end

  def url(...)
    "#{@base_url}#{path(...)}"
  end

  private

  def validate_query_parameters!(params, valid:, required:)
    params = params.keys
    unless (invalid = params - valid).empty?
      raise ArgumentError.new("Invalid query params: #{invalid}")
    end
    unless (missing = required - params).empty?
      raise ArgumentError.new("Missing required params: #{missing}")
    end
  end
end
