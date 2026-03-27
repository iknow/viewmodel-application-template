# frozen_string_literal: true

module MockHelper
  extend ActiveSupport::Concern

  class_methods do
    # Stub a service like "S3Client" with RSpec mocks, with customization of the instance and class doubles.
    #
    # For example
    #    let_service_mock(:s3_client, 'S3Client') { |instance| ... }
    #
    # Introduces
    #   s3_client
    #   s3_client_instance
    #
    # These values can be replaced or refined in subsequent example groups.
    def let_service_mock(name, class_name, configure_class: nil, &configure_instance)
      instance_name = :"#{name}_instance"

      let(name) do
        klass = class_double(class_name)
        allow(klass).to receive(:new) { public_send(instance_name) }
        instance_exec(klass, &configure_class) if configure_class
        klass
      end

      let(instance_name) do
        instance = instance_double(class_name)
        instance_exec(instance, &configure_instance) if block_given?
        instance
      end
    end
  end
end
