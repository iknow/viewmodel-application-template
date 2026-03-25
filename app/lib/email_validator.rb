# frozen_string_literal: true

class EmailValidator < ActiveModel::EachValidator
  def use_blocklist?
    options.fetch(:use_blocklist, true)
  end

  def validate_each(record, attribute, value)
    service = DomainValidatorService.new
    user, domain = value.split('@', 2)

    if user.blank?
      record.errors.add(
        attribute,
        :invalid_email,
        message: 'missing user part')
    end

    if domain.blank?
      record.errors.add(
        attribute,
        :invalid_email,
        message: 'missing domain part')
    end

    return unless domain.present?

    domain = domain.downcase

    unless service.domain?(domain)
      record.errors.add(
        attribute,
        :invalid_email,
        message: 'domain name invalid')

      return
    end

    if use_blocklist? && !service.permitted_domain?(domain)
      record.errors.add(
        attribute,
        :invalid_domain,
        message: "not an accepted email domain (#{domain})")
    end
  end
end
