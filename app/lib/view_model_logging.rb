# frozen_string_literal: true

class ViewModelLogging
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

    message = "Rendered #{status} error '#{exception.class.name}':\n"
    message << filter_error_context(view).to_yaml

    Rails.logger.debug(message)
  end

  # Filter an error context structure that will be logged (or Honeybadgered)
  # using the global privacy filter parameters, which are a subset of the Rails
  # filter parameters. See config/initializers/filter_parameter_logging.rb for
  # details.
  def self.filter_error_context(hash)
    filter = ActiveSupport::ParameterFilter.new(GLOBAL_PRIVACY_FILTER_PARAMETERS)
    filter.filter(hash)
  end

  # Filter the query parameters of a URL using the configured Rails parameter filters
  def self.filter_url_query(url)
    uri = URI.parse(url)

    return url unless uri.query

    params = Rack::Utils.parse_nested_query(uri.query)

    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    filtered_params = filter.filter(params)

    uri.query = Rack::Utils.build_nested_query(filtered_params)

    uri.to_s
  end
end
