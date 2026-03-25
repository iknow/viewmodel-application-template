# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::BackgroundJobProgressesController', type: :request do
  let_factory(:background_job_progress)

  describe 'GET /api/background_job_progress' do
    let(:request_method) { :get }
    let(:request_url) { api_background_job_progress_url(id: background_job_progress.id) }

    let(:expected_result) { be_a_viewmodel_response_of(BackgroundJobProgressView) }

    it_behaves_like 'responds successfully with result'
  end
end
