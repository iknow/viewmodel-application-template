# frozen_string_literal: true

# Like the regular Rails::Generators::ResourceRouteGenerator, but always prepends api, and makes "arvm_resources"

class Rails::ViewmodelApiResourceRouteGenerator < Rails::Generators::NamedBase
  def add_resource_route
    namespace = ['api', *regular_class_path]
    route "arvm_resources :#{file_name.pluralize}", namespace:
  end
end
