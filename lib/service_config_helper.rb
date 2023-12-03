class ServiceConfigHelper
  def self.load_service_config(service_name)
    return {} unless Rails.env.development? || Rails.env.test?

    service_config_file = File.join(Rails.root, 'tmp', "#{service_name}-config.json")
    return {} unless File.exist?(service_config_file)

    JSON.parse(File.read(service_config_file))
  end

  def initialize(service_name)
    @config = self.class.load_service_config(service_name)
  end

  def fetch(var, default)
    ENV.fetch(var, @config.fetch(var, default))
  end
end
