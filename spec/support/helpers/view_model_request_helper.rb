# frozen_string_literal: true

require 'view_model/test_helpers'
require_relative './view_model_helper'

module ViewModelRequestHelper
  extend ActiveSupport::Concern
  extend RSpec::Matchers::DSL

  include ViewModelHelper

  included do
    shared_examples_for 'a privileged controller method' do
      include_examples 'requires login'
      include_examples 'rejects unprivileged auth'
    end

    shared_examples_for 'a method that requires a language' do
      context 'with no language specified' do
        let(:request_params) { super().except(:language) }

        include_examples 'rejects the request', status: 400, code: 'Request.MissingFilter'
      end
    end
  end
end
