# frozen_string_literal: true

module Uploadable
  extend ActiveSupport::Concern

  class_methods do
    attr_reader :default_upload_region, :default_upload_bucket_name, :upload_path_prefix, :valid_content_types
    attr_reader :upload_service_params

    def upload_with(upload_service_class,
                    default_region: upload_service_class.default_region,
                    default_bucket_name: upload_service_class.default_bucket_name,
                    path_prefix: nil,
                    valid_content_types: nil,
                    **upload_service_params)
      unless upload_service_class.is_a?(Class) && upload_service_class <= MediaUploadService
        raise RuntimeError.new("Invalid upload service: #{upload_service_class}")
      end

      @upload_service_class = upload_service_class

      @default_upload_region      = default_region
      @default_upload_bucket_name = default_bucket_name

      @upload_path_prefix    = path_prefix
      @valid_content_types   = valid_content_types.to_set.freeze
      @upload_service_params = upload_service_params.freeze
    end

    def upload_service_class
      unless @upload_service_class
        raise RuntimeError.new("Upload service class not set for #{self.name}")
      end

      @upload_service_class
    end
  end

  delegate :default_upload_region, :default_upload_bucket_name, :upload_path_prefix, to: :class

  def upload_service(region: nil, bucket_name: nil, extra_path_prefix: nil)
    region ||= self.default_upload_region
    bucket_name ||= self.default_upload_bucket_name
    path_prefix = File.join(*[extra_path_prefix, self.upload_path_prefix].compact).presence

    self.class.upload_service_class.new(
      region:,
      bucket_name:,
      path_prefix:,
      media_type: self.class.name,
      valid_content_types: self.class.valid_content_types,
      **self.class.upload_service_params)
  end

  def access_url(raw: false)
    if filename
      self.class.upload_service_class.resource_url(
        region, bucket_name, filename, raw:)
    end
  end
end
