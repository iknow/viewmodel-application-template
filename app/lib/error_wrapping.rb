# frozen_string_literal: true

module ErrorWrapping
  extend ActiveSupport::Concern

  # Catch and translate ActiveRecord errors that map to standard ViewModel errors
  def wrap_active_record_errors(blame_reference)
    yield
  rescue ::ActiveRecord::RecordInvalid => e
    raise ViewModel::DeserializationError::Validation.from_active_model(e.record.errors, blame_reference)
  rescue ::ActiveRecord::StaleObjectError => _e
    raise ViewModel::DeserializationError::LockFailure.new([blame_reference])
  rescue ::ActiveRecord::StatementInvalid, ::ActiveRecord::InvalidForeignKey, ::ActiveRecord::RecordNotSaved => e
    raise ViewModel::DeserializationError::DatabaseConstraint.from_exception(e, [blame_reference])
  end
end
