# frozen_string_literal: true

# The ServiceError is a default super type for error types raised by
# services.
#
# It comes with a sensible renderer and can be handled by the
# default rails handlers without requiring a `rescue_from` in the
# controller.
class ServiceError < ViewModel::AbstractError
  include AdvisoryErrors
end
