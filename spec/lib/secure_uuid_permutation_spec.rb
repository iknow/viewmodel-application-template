# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SecureUuidPermutation do
  let(:uuid) { SecureRandom.uuid }
  let(:secret) { SecureRandom.bytes(16) }

  it 'roundtrips' do
    encrypted = described_class.permute(uuid, secret, forward: true)
    decrypted = described_class.permute(encrypted, secret, forward: false)
    expect(decrypted).to eq(uuid)
  end
end
