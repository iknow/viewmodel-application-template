# frozen_string_literal: true

class ApiClient
  class ApiError < RuntimeError
    attr_reader :request, :response, :response_body

    def initialize(message, request, response = nil, response_body = nil)
      super(message)
      @request = request
      @response = response
      @response_body = response_body
    end

    def to_honeybadger_context
      response_context =
        if response
          json_response_body = JSON.parse(response_body) rescue nil
          {
            status: response.code,
            return_message: response.return_message,
            timed_out: response.timed_out?,
            headers: response.headers,
            body: json_response_body || response_body,
          }
        end

      request_context = request.options.dup
      json_request_body = JSON.parse(request_context[:body]) rescue nil
      request_context[:body] = json_request_body if json_request_body

      context = {
        url: request.base_url.to_s,
        request: request_context,
        response: response_context,
      }

      ViewModelLogging.filter_error_context(context)
    end
  end

  class ApiTimeoutError < ApiError; end
  class ApiConnectionError < ApiError; end

  class ApiResponseError < ApiError; end

  enum :BodyType do
    Json('application/json') do
      def serialize(body)
        JSON.dump(body)
      end

      def deserialize(body)
        JSON.parse(body)
      rescue JSON::ParserError
        raise BodyType::ParseError.new
      end
    end

    Form('application/x-www-form-urlencoded') do
      def serialize(body)
        Rack::Utils.build_query(body)
      end

      def deserialize(body)
        Rack::Utils.parse_query(body)
      end
    end

    NestedForm('application/x-www-form-urlencoded') do
      def serialize(body)
        Rack::Utils.build_nested_query(body)
      end

      def deserialize(body)
        Rack::Utils.parse_nested_query(body)
      end
    end

    attr_reader :content_type

    def init(content_type)
      @content_type = content_type
    end
  end

  class BodyType::ParseError < RuntimeError; end

  ApiResult = Value.new(:code, :request, :response, result: nil)

  def make_form_request(url, body:, **rest, &)
    request_type = BodyType::Form
    make_request(url, request_type:, body:, **rest, &)
  end

  def make_json_request(url, body: nil, **rest, &)
    request_type  = BodyType::Json unless body.nil?
    response_type = BodyType::Json
    make_request(url, request_type:, response_type:, body:, **rest, &)
  end

  def make_request(
    url,
    method: :get,
    headers: {},
    params: {},
    body: nil,
    request_type: nil,
    response_type: nil,
    response_schema: nil,
    timeout: nil,
    &
  )
    streaming = block_given?

    if streaming && response_type
      raise ArgumentError.new('Response type parsing cannot be used when streaming responses')
    end

    if response_schema && response_type.nil?
      raise ArgumentError.new('Response schema validation cannot be used without response type parsing')
    end

    if response_schema && !response_schema.is_a?(JsonSchema::Schema)
      response_schema = JsonSchema.parse!(response_schema)
    end

    if request_type
      headers = headers.merge({ 'Content-Type' => request_type.content_type })
      body = request_type.serialize(body) if body
    end

    if response_type
      headers = headers.merge({ 'Accept' => response_type.content_type })
    end

    if timeout.nil?
      timeout = streaming ? 600 : 60
    end

    request = Typhoeus::Request.new(url, method:, headers:, params:, body:, timeout:)

    if streaming
      failed = false
      streamed_error = +''

      request.on_headers do |response|
        failed = true unless response.code >= 200 && response.code <= 299
      end

      # failure such as a timeout or disconnection
      request.on_failure do |_response|
        failed = true
      end

      request.on_body do |chunk, _response|
        if failed
          streamed_error << chunk
        else
          yield(chunk)
        end
      end
    end

    response = request.run

    unless response.success?
      error_body = streaming ? streamed_error : response.body

      if response.timed_out?
        raise ApiTimeoutError.new('request timed out', request, response, error_body)
      elsif response.code == 0
        message = "request failed: #{response.return_message}"
        raise ApiConnectionError.new(message, request, response, error_body)
      else
        message = "request returned non-successful HTTP status: #{response.code}"
        raise ApiError.new(message, request, response, error_body)
      end
    end

    if streaming
      ApiResult.with(code: response.code, request:, response:)
    else
      result = response.body

      if response_type
        result =
          begin
            response_type.deserialize(result)
          rescue BodyType::ParseError => e
            raise ApiResponseError.new("Could not parse response body as #{response_type.name}: #{e.message}", request, response, response.body)
          end

        if response_schema
          valid, errors = response_schema.validate(result)

          unless valid
            errors_description = errors.map { |e| "#{e.pointer}: #{e.message}" }.join('; ')
            raise ApiResponseError.new(
                    "Response format didn't match schema: #{errors_description}", request, response, response.body)
          end
        end
      end

      ApiResult.with(code: response.code, result:, request:, response:)
    end
  end
end
