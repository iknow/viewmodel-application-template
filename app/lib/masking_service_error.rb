# frozen_string_literal: true

class MaskingServiceError < ServiceError
  attr_reader :masked_error

  def initialize(masked_error)
    super()
    @masked_error = masked_error
  end

  def honeybadger_message
    "#{@masked_error.message} (via #{self.message})"
  end

  def honeybadger_error_class
    @masked_error.class
  end

  def honeybadger_error_name
    @masked_error.class.name
  end

  def honeybadger_backtrace
    @masked_error.backtrace
  end

  def honeybadger_cause
    # extracted from Honeybadger::Notice.exception_cause
    e = @masked_error.cause
    if e.respond_to?(:cause) && e.cause && e.cause.is_a?(Exception)
      e.cause
    elsif e.respond_to?(:original_exception) && e.original_exception && e.original_exception.is_a?(Exception)
      e.original_exception
    elsif e.respond_to?(:continued_exception) && e.continued_exception && e.continued_exception.is_a?(Exception)
      e.continued_exception
    end
  end

  def to_honeybadger_context
    if @masked_error.respond_to?(:to_honeybadger_context)
      @masked_error.to_honeybadger_context
    else
      {}
    end
  end
end
