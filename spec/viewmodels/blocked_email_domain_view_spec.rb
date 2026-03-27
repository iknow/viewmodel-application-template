# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BlockedEmailDomainView, type: :viewmodel do
  let_factory(:blocked_email_domain)

  it "doesn't raise on roundtrip" do
    expect do
      alter_by_view!(BlockedEmailDomainView, blocked_email_domain) do |_view, _refs|
      end
    end.to_not raise_error
  end

  it_behaves_like 'can run all defined migrations', BlockedEmailDomainView do
    let(:latest_version_view) { serialize_to_hash_with_refs(BlockedEmailDomainView.new(blocked_email_domain)) }
  end
end
