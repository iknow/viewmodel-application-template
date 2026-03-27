# frozen_string_literal: true

class SecureUuidPermutation
  # Securely permutes the 128-bit uuid with one round of a 128-bit block cipher
  def self.permute(uuid, secret, forward: true)
    uuid_bytes = UuidAbbreviator.to_bytes(uuid)

    cipher = OpenSSL::Cipher.new('aes-128-ecb')

    if forward
      cipher.encrypt
    else
      cipher.decrypt
    end

    cipher.key = secret
    cipher.padding = 0

    cipherbytes = cipher.update(uuid_bytes)
    cipherbytes += cipher.final

    UuidAbbreviator.from_bytes(cipherbytes)
  end
end
