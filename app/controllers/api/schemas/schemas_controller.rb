# frozen_string_literal: true

module Api::Schemas
  class SchemasController < ::Api::ApplicationController
    def self.all_viewmodel_classes
      classes = ViewModel::Registry.all.uniq

      classes.sort_by(&:view_name)
    end

    class ViewModelPathSerializer < ParamSerializers::ViewModelClass
      def load(str)
        view_name = str.camelize.gsub('::', '.')
        vm_class = super(view_name)

        vm_class
      end

      def dump(clazz, json: nil)
        super.gsub('.', '::').underscore
      end

      set_singleton!
    end

    def index
      viewmodel_classes = self.class.all_viewmodel_classes
      views = viewmodel_classes.map do |viewmodel_class|
        construct_view(viewmodel_class)
      end

      render_viewmodel(views, serialize_context: Schemas::SchemaBaseView.new_serialize_context)
    end

    def show
      viewmodel_class = parse_param(:id, with: ViewModelPathSerializer)
      render_viewmodel(construct_view(viewmodel_class))
    end

    def construct_view(viewmodel_class)
      Schemas::SchemaBaseView.for_viewmodel(viewmodel_class).new(viewmodel_class)
    end
  end
end
