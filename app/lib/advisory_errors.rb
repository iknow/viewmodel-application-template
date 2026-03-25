# frozen_string_literal: true

module AdvisoryErrors
  extend ActiveSupport::Concern

  # Determine if this error should be reported to external monitoring.
  #
  # By default, only 500-class errors are reported. Subclasses may override this
  # to force reporting, or by using the `reportable!` helper. This is useful
  # when we need to know about a failure, but also want to return a 400-class
  # error.
  def reportable?
    !status.is_a?(Numeric) || status >= 500
  end

  # Determine if this error is reported as advisory.
  def advisory?
    false
  end

  class_methods do
    # Force instances of this non-500 status Error class to be reported to
    # honeybadger as advisory errors.
    def reportable!
      define_method(:reportable?) { true }
      define_method(:advisory?) { true }
    end
  end
end
