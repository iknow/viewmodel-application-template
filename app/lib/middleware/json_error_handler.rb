# frozen_string_literal: true

# On failing to parse JSON parameters, Rails' middleware raises an
# ActionDispatch parse error that is rendered at a low level. Catch it and
# transform it to a formatted viewmodel error.
module Middleware; end
class Middleware::JsonErrorHandler
  class ParseError < ViewModel::Error
    status 400
    code 'InvalidJson'

    def initialize(message)
      super()

      @message = message
    end

    def detail
      "Unable to parse invalid JSON request: #{@message}"
    end

    def meta
      { error: @message }
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue ActionDispatch::Http::Parameters::ParseError => e
    viewmodel_error =
      begin
        raise ParseError.new(e.message)
      rescue ParseError => e
        e
      end

    # The ActionDispatch error is thrown after Rails begins processing the
    # request, so before we can use ApplicationController to render our error we
    # have to reset ActionDispatch's state (to prevent a double-render error)
    env.delete_if { |k, _v| k =~ /^action_dispatch\./ }

    # Mask the JSON content type so Rails doesn't attempt to parse it again
    env['CONTENT_TYPE'] = 'application/octet-stream'

    env['rack.viewmodel.error'] = viewmodel_error
    return Api::ApplicationController.action(:render_error_from_middleware).call(env)
  end
end
