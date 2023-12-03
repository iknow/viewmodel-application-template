# frozen_string_literal: true

class ViewModelLogging
  # In some circumstances error views may contain sensitive information. Provide
  # a list of keys to keep out of the Rails log.
  ERROR_LOG_FILTER = ['meta.password'].freeze

  def self.log_error(error)
    error_view =
      if error.is_a?(ViewModel::AbstractError)
        error.view
      else
        ViewModel::WrappedExceptionError.new(error, 500, nil).view
      end

    log_rendered_error(error_view, error_view.status)
  end

  def self.log_rendered_error(error_view, status)
    exception = error_view.model.exception
    view      = error_view.serialize_to_hash

    # Exception backtrace will be re-rendered whether or not it's included in the view, using a backtrace_cleaner.
    exception_view = (view['exception'] ||= {})
    exception_view.delete('backtrace')
    if exception.backtrace
      exception_view['backtrace'] = Rails.backtrace_cleaner.clean(exception.backtrace)
    end

    filter = ActiveSupport::ParameterFilter.new(ERROR_LOG_FILTER)

    message = +"Rendered #{status} error '#{exception.class.name}':\n"
    message << filter.filter(view).to_yaml

    Rails.logger.debug(message)
  end
end
