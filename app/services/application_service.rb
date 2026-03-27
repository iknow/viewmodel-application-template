# frozen_string_literal: true

class ApplicationService
  include ViewModel::ErrorWrapping

  attr_reader :request_context

  delegate :permissions, :resource_owner, to: :request_context

  delegate :authorize!, :authorize_ability!,
           :authorize_ability_for_all_orgs!, :authorize_ability_for_any_org!,
           to: :permissions

  def initialize(request_context)
    @request_context = request_context
  end

  # Report a request error from upstream services to the Rails log and add its
  # context details to Honeybadger before swallowing the actual exception.
  def record_service_faraday_error(service_name, error)
    message = "Error accessing #{service_name}: #{error.message}"
    Rails.logger.warn(message)

    # Attempt to extract request details where possible
    request =
      case error.response
      when nil
        nil
      when Faraday::Response
        body = error.response.env.request_body
        JSON.parse(body) rescue body
      else
        error.response[:request]
      end

    context = ViewModelLogging.filter_error_context({
      service: service_name,
      response_status: error.response_status,
      response: error.response_body,
      request:,
    })

    Honeybadger.context(context)
  end
end
