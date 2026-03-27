# frozen_string_literal: true

class CdnConfig < LoadableConfig
  CDN_DOMAINS_SCHEMA = JsonSchemaHelper.build do
    array(
      object({
        region: string,
        bucket_name: string,
        url_prefix: string(format: 'uri'),
      }),
    )
  end

  class MappingSerializer
    def self.load(cdn_domains)
      cdn_domains.each_with_object({}) do |cd, mapping|
        key = [cd['region'], cd['bucket_name']]
        mapping[key] = cd['url_prefix']
      end
    end
  end

  attribute :cdn_domains, schema: CDN_DOMAINS_SCHEMA, serializer: MappingSerializer

  config_file 'config/app/cdn.yml'

  class << self
    delegate :cdn_domain, :all_cdn_domains, to: :instance
  end

  def cdn_domain(region, bucket)
    cdn_domains[[region, bucket]]
  end

  def all_cdn_domains
    cdn_domains.values.map do |url_prefix|
      URI(url_prefix).host
    end
  end
end
