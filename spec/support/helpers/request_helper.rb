# frozen_string_literal: true

module RequestHelper
  extend ActiveSupport::Concern

  # Demo application stub authentication
  def new_auth_without_abilities(user)
    { 'Authorization' => "Bearer #{user.email}" }
  end

  # Demo app users don't inherently bear abilities
  def new_auth_with_abilities(user)
    new_auth_without_abilities(user)
  end

  def request_params
    {}
  end

  def request_headers
    {}
  end

  def request_method
    :get
  end

  def request_encoding
    :json
  end

  def make_request(params: {}, headers: {}, **args)
    if [:post, :put].include?(request_method) and request_encoding.present?
      # We expect all our API POST requests to be JSON.
      args = args.merge(as: request_encoding)
    end

    self.send(request_method,
              request_url,
              params: params.merge(request_params),
              headers: headers.merge(request_headers),
              **args)
  end
end
