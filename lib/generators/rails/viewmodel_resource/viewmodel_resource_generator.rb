# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/rails/resource/resource_generator'

class Rails::ViewmodelResourceGenerator < Rails::Generators::ResourceGenerator
  hook_for :resource_viewmodel, as: :resource, required: true
end
