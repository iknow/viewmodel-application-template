# frozen_string_literal: true

class UuidAbbreviator
  def self.to_bytes(uuid)
    BaseX::Base16.decode(uuid.tr('-', ''))
  end

  def self.from_bytes(bytes)
    chars = BaseX::Base16.encode(bytes)
    chars.match(/^(\h{8})(\h{4})(\h{4})(\h{4})(\h{12})$/).captures.join('-')
  end

  def self.abbreviate(uuid)
    Base64.urlsafe_encode64(to_bytes(uuid), padding: false)
  end

  def self.expand(abbreviation)
    from_bytes(Base64.urlsafe_decode64(abbreviation))
  end
end
