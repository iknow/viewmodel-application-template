# frozen_string_literal: true

class Rails::ViewmodelViewSpecGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_viewmodel_spec
    template_file = 'viewmodel_spec.rb'
    template template_file, File.join('spec/viewmodels', class_path, "#{file_name}_view_spec.rb")
  end

  private

  def view_name
    class_name + 'View'
  end

  def factory_name
    class_name.gsub('::', '').underscore
  end
end
