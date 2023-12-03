# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserView, type: :viewmodel do
  let_factory(:user)

  it "doesn't raise on roundtrip" do
    expect do
      alter_by_view!(UserView, user) do |_view, _refs|
      end
    end.to_not raise_error
  end

  it_behaves_like 'can run all defined migrations', UserView do
    let(:latest_version_view) { serialize_to_hash_with_refs(UserView.new(user)) }
  end
end
