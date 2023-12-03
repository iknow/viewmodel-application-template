# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/resource_helpers'

class Rails::ViewmodelApiControllerSpecGenerator < Rails::Generators::NamedBase
  include Rails::Generators::ResourceHelpers

  source_root File.expand_path('templates', __dir__)

  def create_controller_spec_files
    template_file = 'controller_spec.rb'
    api_class_path = ['api', *controller_class_path]
    template template_file, File.join('spec/requests', api_class_path, "#{controller_file_name}_controller_spec.rb")
  end

  private

  def factory_name
    class_name.gsub('::', '').underscore
  end

  def fetch_all_url
    (['api'] + controller_class_path + [controller_file_name]).join('/')
  end

  def fetch_all_route_helper
    (['api'] + controller_class_path + [controller_file_name, 'url']).join('_')
  end

  def fetch_one_url
    (['api'] + controller_class_path + [controller_file_name.singularize]).join('/')
  end

  def fetch_one_route_helper
    (['api'] + controller_class_path + [controller_file_name.singularize, 'url']).join('_')
  end

  def view_name
    class_name + 'View'
  end
end
