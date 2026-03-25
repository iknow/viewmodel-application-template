# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BackgroundJobProgressView, type: :viewmodel do
  let_factory(:background_job_progress)

  it "doesn't raise on roundtrip" do
    expect do
      alter_by_view!(BackgroundJobProgressView, background_job_progress) do |_view, _refs|
      end
    end.to_not raise_error
  end

  it_behaves_like 'can run all defined migrations', BackgroundJobProgressView do
    let(:latest_version_view) { serialize_to_hash_with_refs(BackgroundJobProgressView.new(background_job_progress)) }
  end
end
