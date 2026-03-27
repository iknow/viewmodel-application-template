# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiClient do
  subject { ApiClient.new }
  describe '#make_request' do
    context 'when making a successful request' do
      let(:url) { 'http://example.com/api/success' }
      let(:json_body) { { 'message' => 'Success!' } }
      let(:body) { JSON.dump(json_body) }

      context 'without a request body' do
        it 'returns a successful response without parsing' do
          stub_request(:get, url).to_return(status: 200, body:)

          response = subject.make_request(url)

          expect(response.code).to eq(200)
          expect(response.result).to eq(body)
        end

        it 'returns a successful response with JSON parsing' do
          stub_request(:get, url).to_return(status: 200, body:)

          response = subject.make_json_request(url)

          expect(response.code).to eq(200)
          expect(response.result).to eq(json_body)
        end

        context 'with schema validation' do
          let(:url) { 'http://example.com/api/json' }
          let(:response_schema) do
            {
              'type' => 'object',
              'properties' => {
                'name' => { 'type' => 'string' },
                'age' => { 'type' => 'integer' },
              },
              'required' => ['name', 'age'],
            }
          end

          it 'requires json response parsing' do
            expect {
              subject.make_request(url, response_schema:)
            }.to raise_error(ArgumentError, /Response schema validation cannot be used without response type parsing/)
          end

          context 'with a matching response' do
            let(:json_body) { { 'name' => 'John Doe', 'age' => 30 } }

            it 'returns a successful response' do
              stub_request(:get, url).to_return(status: 200, body:)

              response = subject.make_json_request(url, response_schema:)

              expect(response.code).to eq(200)
              expect(response.result).to eq(json_body)
            end
          end

          context 'with a non-matching response' do
            let(:json_body) { { 'name' => 'John Doe', 'age' => 'thirty' } }

            it 'raises an ApiResponseError when response does not match the schema' do
              stub_request(:get, url).to_return(status: 200, body:)

              expect {
                subject.make_json_request(url, response_schema:)
              }.to raise_error(
                     ApiClient::ApiResponseError,
                     %r{Response format didn't match schema: #/age:},
                   )
            end
          end
        end
      end

      context 'with a request body' do
        let(:json_request_body) { { 'query' => 'success' } }
        let(:request_body) { JSON.dump(json_request_body) }

        it 'returns a successful response without parsing' do
          stub_request(:post, url).with(body: request_body).to_return(status: 200, body:)

          response = subject.make_request(url, method: :post, body: request_body)

          expect(response.code).to eq(200)
          expect(response.result).to eq(body)
        end

        it 'returns a successful response with JSON parsing' do
          stub_request(:post, url).with(body: request_body).to_return(status: 200, body:)

          response = subject.make_json_request(url, method: :post, body: json_request_body)

          expect(response.code).to eq(200)
          expect(response.result).to eq(json_body)
        end
      end
    end

    context 'when making a request with streaming' do
      let(:url) { 'http://example.com/api/stream' }

      it 'yields the streamed response' do
        response_body = 'Chunky chunks'
        stub_request(:get, url).to_return(status: 200, body: response_body)

        chunks = []
        response = subject.make_request(url) do |chunk|
          chunks << chunk
        end

        expect(chunks).to eq([response_body])
        expect(response.code).to eq(200)
        expect(response.result).to be_nil
      end

      it 'does not permit a json response' do
        expect {
          subject.make_request(url, response_type: ApiClient::BodyType::Json) { |_| nil }
        }.to raise_error(ArgumentError, /Response type parsing cannot be used when streaming/)
      end
    end

    context 'when making a failed request' do
      let(:url) { 'http://example.com/api/failure' }

      context 'without streaming' do
        it 'raises an ApiError with appropriate message and body on 4xx' do
          stub_request(:get, url).to_return(status: 404, body: 'Not Found')

          expect {
            subject.make_request(url)
          }.to raise_error(ApiClient::ApiError) do |err|
            expect(err.message).to match(/request returned non-successful HTTP status: 404/)
            expect(err.response_body).to eq('Not Found')
          end
        end

        it 'raises an ApiError with appropriate message on timeout' do
          stub_request(:get, url).to_timeout

          expect {
            subject.make_request(url)
          }.to raise_error(ApiClient::ApiError, /request timed out/)
        end

        it 'raises an ApiError with appropriate message on parse error' do
          stub_request(:get, url).to_return(status: 200, body: 'not json')

          expect {
            subject.make_json_request(url)
          }.to raise_error(ApiClient::ApiResponseError, /Could not parse response body/)
        end

        it 'raises an ApiError with appropriate message on other error' do
          # We can't webmock a failure, but we can return status of 0 which is how
          # it's detected. Because the failure isn't real, there won't be a
          # legitimate return_message.
          stub_request(:get, url).to_return(status: 0, body: '')

          expect {
            subject.make_request(url)
          }.to raise_error(ApiClient::ApiError, /request failed:/)
        end
      end

      context 'with streaming' do
        it 'raises an ApiError with appropriate message and body on 4xx' do
          stub_request(:get, url).to_return(status: 404, body: 'Not Found')

          expect {
            subject.make_request(url) { |_| raise 'callback should not be called' }
          }.to raise_error(ApiClient::ApiError) do |err|
            expect(err.message).to match(/request returned non-successful HTTP status: 404/)
            expect(err.response_body).to eq('Not Found')
          end
        end

        it 'raises an ApiError with appropriate message on timeout' do
          stub_request(:get, url).to_timeout

          expect {
            subject.make_request(url) { |_| raise 'callback should not be called' }
          }.to raise_error(ApiClient::ApiError, /request timed out/)
        end

        it 'raises an ApiError with appropriate message on other error' do
          # We can't webmock a failure, but we can return status of 0 which is how
          # it's detected. Because the failure isn't real, there won't be a
          # legitimate return_message.
          stub_request(:get, url).to_return(status: 0, body: '')

          expect {
            subject.make_request(url) { |_| raise 'callback should not be called' }
          }.to raise_error(ApiClient::ApiError, /request failed:/)
        end
      end
    end
  end
end
