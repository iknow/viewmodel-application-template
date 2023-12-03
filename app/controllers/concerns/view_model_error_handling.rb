# frozen_string_literal: true

# ViewModel rendering for non-viewmodel errors.
module ViewModelErrorHandling
  extend ActiveSupport::Concern

  included do
    rescue_from IknowParams::Parser::ParseError, with: ->(ex) { render_exception(ex, status: 400) }
    rescue_from ActiveRecord::RecordNotFound,    with: ->(ex) { render_exception(ex, status: 404) }
  end

  def render_exception(exception, status: 500, code: nil)
    render_error(ViewModel::WrappedExceptionError.new(exception, status, code).view, status)
  end

  # For unexpected exceptions that we will wrap and render as a 500, sanitize
  # the error message before rendering to guard against exposing potential
  # private information in arbitrary exception messages.
  def render_sanitized_exception(exception, status: 500, code: nil)
    if Rails.env.production?
      render_error(SanitizedExceptionError.new(exception, status, code).view, status)
    else
      render_exception(exception, status:, code:)
    end
  end

  class SanitizedExceptionError < ViewModel::WrappedExceptionError
    def detail
      "An unexpected error occurred: #{exception.class.name}"
    end
  end
end
