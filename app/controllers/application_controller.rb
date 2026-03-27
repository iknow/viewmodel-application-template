# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include IknowParams::Parser

  def front_end_path(resource, *params)
    FrontendRoutes.new(request.base_url).path(resource, *params)
  end

  def front_end_url(brand, resource, *positional_url_params, **query_params)
    default_domain = brand.brand_domains.default
    FrontendRoutes.new(default_domain.env_uri).url(resource, *positional_url_params, **query_params)
  end

  def redirect_to_front_end_url(...)
    redirect_to front_end_url(...), allow_other_host: true
  end
end
