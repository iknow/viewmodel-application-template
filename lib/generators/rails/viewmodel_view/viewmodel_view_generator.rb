# frozen_string_literal: true

class Rails::ViewmodelViewGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  argument :attributes, type: :array, default: [], banner: 'field[:type][:index] field[:type][:index]'

  hook_for :resource_viewmodel_spec, required: true

  def create_viewmodel_files
    template_file = 'viewmodel.rb'
    template template_file, File.join('app/viewmodels', class_path, "#{file_name}_view.rb")
  end

  private

  def vm_attribute_names
    @vm_attribute_names ||= attributes.filter { |a| !a.reference? }.map { |a| ":#{a.name}" }
  end

  def vm_association_names
    @vm_association_names ||= attributes.filter { |a| a.reference? }.map { |a| ":#{a.name}" }
  end
end
