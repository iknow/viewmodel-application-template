# frozen_string_literal: true

class MockLoadableConfig
  def self.new(loadable_config, **values)
    attribute_names = loadable_config._attributes.map { |attr| attr.name.to_sym }

    attribute_names.each do |name|
      unless values.has_key?(name)
        values[name] = loadable_config.instance.public_send(name)
      end
    end

    unless (values.keys - attribute_names).empty?
      raise ArgumentError.new("Unknown attributes for #{loadable_config.name}: #{values.keys.inspect}")
    end

    values.freeze

    mock = Class.new(loadable_config) do
      define_singleton_method(:_mock_attribute_values) { values }

      # rubocop:disable Lint/MissingSuper
      def initialize
        self.freeze
      end
      # rubocop:enable Lint/MissingSuper

      attribute_names.each do |name|
        define_method(name) { self.class._mock_attribute_values.fetch(name) }
      end
    end

    mock.instance
  end
end
