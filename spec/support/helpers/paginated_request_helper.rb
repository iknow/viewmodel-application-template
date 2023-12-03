# frozen_string_literal: true

module PaginatedRequestHelper
  extend ActiveSupport::Concern
  extend RSpec::Matchers::DSL

  included do
    # Shared examples to test controller method pagination. Requires `request_url` in scope.
    shared_examples_for 'a paginated request' do |pagination_method|
      define_method(:make_paginated_request) do |dir|
        make_request(params: { order: pagination_method, direction: dir })
      end
      describe "by #{pagination_method}" do
        it 'should return paginated results forward' do
          make_paginated_request('asc')
          expect(response).to be_json_success_response(200)
          expect(json_response)
            .to include('meta' => include(
                          'pagination' => include(
                            'order'     => pagination_method,
                            'direction' => 'asc')))
        end

        it 'should return paginated results backward' do
          make_paginated_request('desc')
          expect(response).to be_json_success_response(200)
          expect(json_response)
            .to include('meta' => include(
                          'pagination' => include(
                            'order'     => pagination_method,
                            'direction' => 'desc')))
        end
      end
    end

    shared_examples_for 'a default pagination of' do |pagination_method, dir|
      it 'should return results paginated in the expected order' do
        make_request(params: { start: 0 })
        expect(response).to be_json_success_response(200)
        expect(json_response)
          .to include('meta' => include(
                        'pagination' => include(
                          'order'     => pagination_method,
                          'direction' => dir)))
      end
    end
  end
end
