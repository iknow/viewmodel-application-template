# frozen_string_literal: true

module JsonResponseHelper
  extend RSpec::Matchers::DSL

  def json_response
    MultiJson.decode(response.body)
  end

  def response_data
    expect(json_response).to have_key('data')
    json_response['data']
  end

  def response_refs
    expect(json_response).to have_key('data').and have_key('references')
    json_response['references']
  end

  def response_error
    expect(json_response).to have_key('error')
    json_response['error']
  end

  def response_error_meta
    expect(response_error).to have_key('meta')
    response_error['meta']
  end

  def response_meta
    expect(json_response).to have_key('meta')
    json_response['meta']
  end

  def response_supplementary_data(id, field)
    meta = response_meta
    expect(meta).to have_key('supplementary')
    sd = meta['supplementary']
    expect(sd).to have_key(id)
    sd_entry = sd[id]
    expect(sd_entry).to have_key(field)
    sd_entry[field]
  end

  def be_a_viewmodel_response_of(viewmodel, id: a_uuid, **attrs)
    matcher = be_a(Hash) & include(ViewModel::TYPE_ATTRIBUTE => viewmodel.view_name)
    matcher &= include(attrs.stringify_keys) if attrs.present?
    matcher &= include(ViewModel::ID_ATTRIBUTE => id) if id
    matcher
  end

  def be_an_error_response_of(code, **attrs)
    be_a_viewmodel_response_of(ViewModel::ErrorView, id: nil, code:, **attrs)
  end

  def be_a_reference_hash(ref = String)
    match({ ViewModel::REFERENCE_ATTRIBUTE => ref })
  end

  def refer_to_a_viewmodel_response_of(viewmodel, in_refs: response_refs, **attrs)
    be_a_reference_hash & be_passed_to do |h|
      ref = h[ViewModel::REFERENCE_ATTRIBUTE]
      in_refs[ref]
    end.returning(be_a_viewmodel_response_of(viewmodel, **attrs))
  end

  matcher (:be_json_success_response) do |expected_status|
    match do |response|
      response.status == expected_status && valid_json?
    end

    failure_message do |response|
      but = case
            when !valid_json?
              'the response could not be parsed as JSON'
            when (actual_status = response.status) != expected_status
              "status was #{actual_status}"
            else
              raise ArgumentError.new('unexpected case')
            end

      format_but(expected_status, response, but)
    end

    def valid_json?
      MultiJson.decode(response.body)
      true
    rescue MultiJson::ParseError
      false
    end

    def format_but(expected_status, response, but)
      "expected response to be JSON success with status #{expected_status}, " \
      "but #{but}\n" \
      "#{JsonMatcherUtils.format_response(response)}"
    end
  end

  matcher (:be_response_with_status) do |expected_status|
    match do |response|
      RSpec::Rails::Matchers::HaveHttpStatus.matcher_for_status(expected_status).matches?(response)
    end

    failure_message do |response|
      "expected response to have status #{expected_status}, " \
      "but status was #{response.status}\n" \
      "#{JsonMatcherUtils.format_response(response)}"
    end
  end

  matcher (:be_json_error_response) do |expected_status, expected_code|
    match do |response|
      response.status == expected_status && parse_code(response) == expected_code
    end

    def parse_code(response)
      json_body = MultiJson.decode(response.body)
      if (error = json_body['error']).is_a?(Hash)
        error['code']
      end
    rescue MultiJson::ParseError
      nil
    end

    failure_message do |response|
      json_body = begin
                    MultiJson.decode(response.body)
                  rescue MultiJson::ParseError
                    next format_but(expected_status, expected_code, response, 'could not be parsed as JSON')
                  end

      but = case
            when (actual_status = response.status) != expected_status
              "status was #{actual_status}"
            when !json_body.has_key?('error')
              "did not have key 'error'"
            when !json_body['error'].is_a?(Hash)
              'error was not a hash'
            when !json_body['error'].has_key?('code')
              'error did not have a code'
            when (actual_code = json_body['error']['code']) != expected_code
              "error code was '#{actual_code}'"
            else
              raise ArgumentError.new('unexpected case')
            end

      format_but(expected_status, expected_code, response, but)
    end

    def format_but(expected_status, expected_code, response, but)
      "expected response to be JSON error with status #{expected_status} and code '#{expected_code}', " \
      "but #{but}\n" \
      "#{JsonMatcherUtils.format_response(response)}"
    end
  end

  matcher :be_validation_error do |expected_attribute, expected_error|
    match do |response_error|
      actual_attribute, actual_error = parse_error(response_error)
      expected_attribute.to_s == actual_attribute && expected_error.to_s == actual_error
    end

    failure_message do |response_error|
      actual_attribute, actual_error = parse_error(response_error)
      "expected error to be '#{expected_error}' for attribute '#{expected_attribute}'\n" \
        "but was '#{actual_error}' for attribute '#{actual_attribute}'"
    end

    def parse_error(response_error)
      attribute, details = response_error.fetch('meta').fetch_values('attribute', 'details')
      validation_error   = details.fetch('error')
      [attribute, validation_error]
    end
  end

  module JsonMatcherUtils
    def self.format_response(response)
      self.prune_error_response(MultiJson.decode(response.body)).to_yaml
    rescue MultiJson::ParseError
      response.body
    end

    private

    def self.prune_error_response(error_response)
      error_response['error'] = prune_error(error_response['error'])
      error_response
    end

    def self.prune_error(error_hash)
      if error_hash.is_a?(Hash)
        error_hash.dig('exception', 'backtrace')&.tap do |bt|
          bt = bt.take(10) unless ENV['BACKTRACE']
          error_hash['exception']['backtrace'] = bt.join("\n")
        end

        error_hash.dig('exception', 'cause', 'backtrace')&.tap do |bt|
          bt = bt.take(5) unless ENV['BACKTRACE']
          error_hash['exception']['cause']['backtrace'] = bt.join("\n")
        end
      end

      error_hash
    end
  end
end
