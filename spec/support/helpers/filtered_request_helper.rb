# frozen_string_literal: true

module FilteredRequestHelper
  extend ActiveSupport::Concern
  extend RSpec::Matchers::DSL

  # Shared examples to test controller method filtering. Requires from context:
  # `request_url`
  # `filters`: a map of { filter_name => filter_value } that will return exactly one result.
  # `expected_result`: the value that should be returned from the filtered results
  included do
    shared_examples_for 'a filtered request' do |strategy: :both|
      def match_expected_result
        expected_results = Array.wrap(expected_result)

        expected_matchers = expected_results.map do |result|
          have_key(ViewModel::TYPE_ATTRIBUTE) && include(ViewModel::ID_ATTRIBUTE => result.id)
        end

        contain_exactly(*expected_matchers)
      end

      # Ensure the expected result is materialized
      let!(:expected_result) { super() }

      if strategy == :default
        it 'should return a filtered result using default' do
          make_request(params: { **filters })
          expect(response).to be_json_success_response(200)
          expect(response_data).to match_expected_result
        end
      else
        # Explicitly select one or both strategies
        unless strategy == :search
          it 'should return a filtered result using scope' do
            make_request(params: { **filters, resolution_strategy: 'scope' })
            expect(response).to be_json_success_response(200)
            expect(response_data).to match_expected_result
          end
        end

        unless strategy == :scope
          it 'should return a filtered result using search' do
            make_request(params: { **filters, resolution_strategy: 'search' })
            expect(response).to be_json_success_response(200)
            expect(response_data).to match_expected_result
          end
        end
      end
    end
  end
end
