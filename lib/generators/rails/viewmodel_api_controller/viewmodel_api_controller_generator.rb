# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/rails/scaffold_controller/scaffold_controller_generator'

class Rails::ViewmodelApiControllerGenerator < Rails::Generators::ScaffoldControllerGenerator
  source_root File.expand_path('templates', __dir__)

  hook_for :resource_controller_spec, required: true

  def create_controller_files # override
    template_file = 'controller.rb'
    api_class_path = ['api', *controller_class_path]
    template template_file, File.join('app/controllers', api_class_path, "#{controller_file_name}_controller.rb")
  end
end
