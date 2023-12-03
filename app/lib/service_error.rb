# frozen_string_literal: true

class ServiceError < ViewModel::AbstractError
  # The ServiceError is a default super type for error types raised by
  # services.
  #
  # It comes with a sensible renderer and can be handled by the
  # default rails handlers without requiring a `rescue_from` in the
  # controller.
  #
  # The interface is the same as for ViewModel::AbstractError.
end
