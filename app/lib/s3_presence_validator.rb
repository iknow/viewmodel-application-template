# frozen_string_literal: true

class S3PresenceValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    region, bucket, path =
      begin
        S3Client.parse_url(value)
      rescue ArgumentError => e
        record.errors.add(attribute, :invalid_s3_url, message: "must be a valid s3 url (#{e.message})")
        return
      end

    client = S3Client.new(region:, bucket_name: bucket)
    begin
      client.head(path)
    rescue S3Client::ReadError => e
      record.errors.add(attribute, :missing_s3_resource, message: "must refer to a resource that is present on S3 (#{e.message})")
    end
  end
end
