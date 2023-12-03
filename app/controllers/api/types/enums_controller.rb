# frozen_string_literal: true

module Api::Types
  class EnumsController < ::Api::ApplicationController
    ADDITIONAL_ENUM_CLASSES = [].freeze

    def self.all_enum_classes
      classes = ApplicationRecord.subclasses.select { |c| c < PersistentEnum::ActsAsEnum } +
                ADDITIONAL_ENUM_CLASSES

      classes.sort_by(&:name)
    end

    # paths to an enum type are constructed as pluralized underscored class name
    class EnumPathSerializer < ParamSerializers::Class
      def initialize
        super(Object)
      end

      def matches_type?(val)
        super && EnumsController.all_enum_classes.include?(val)
      end

      def load(str)
        super(str.singularize.camelize)
      end

      def dump(clazz, json: nil)
        super.underscore.pluralize
      end

      set_singleton!
    end

    def index
      enum_classes = self.class.all_enum_classes

      views = enum_classes.map do |enum_class|
        construct_view(enum_class)
      end

      render_viewmodel(views, serialize_context: Enums::EnumBaseView.new_serialize_context)
    end

    def show
      model_class = parse_param(:id, with: EnumPathSerializer)
      view = construct_view(model_class)
      render_viewmodel(view)
    end

    def construct_view(enum_class)
      Enums::EnumBaseView.for_model(enum_class).new(enum_class)
    end
  end
end
