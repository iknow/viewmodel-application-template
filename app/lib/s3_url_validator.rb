# frozen_string_literal: true

class S3UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    S3Client.parse_url(value)
  rescue ArgumentError => e
    record.errors.add(attribute, :invalid_s3_url, message: "must be a valid s3 url (#{e.message})")
  end
end
