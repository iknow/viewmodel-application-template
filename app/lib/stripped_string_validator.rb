# frozen_string_literal: true

class StrippedStringValidator < ActiveModel::EachValidator
  LEADING_WHITESPACE  = /\A[\p{Space}]/.freeze
  TRAILING_WHITESPACE = /[\p{Space}]\Z/.freeze

  def validate_each(record, attribute, value)
    if value && value.is_a?(String) && (LEADING_WHITESPACE.match?(value) || TRAILING_WHITESPACE.match?(value))
      record.errors.add(attribute, :unstripped_string, message: 'must not have leading or trailing whitespace')

      # Temporarily: yell at Honeybadger because we want to know if clients are being rejected with unstripped strings
      Honeybadger.notify(
        "[TEMPORARY] Unstripped String rejected in update to #{record.class}",
        context: {
          type: record.class.name,
          id: record.id,
          attribute:,
          value:,
        })
    end
  end
end
