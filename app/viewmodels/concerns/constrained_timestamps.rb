# frozen_string_literal: true

module ConstrainedTimestamps
  extend ActiveSupport::Concern

  # Attempting to set updated_at to anything other than the existing value will
  # cause it to be marked as changed and explicitly bumped to the current time.
  def deserialize_updated_at(value, references:, deserialize_context:)
    value = _deserialize_timestamp('updated_at', value)

    if value != self.updated_at
      attribute_changed!(:updated_at)
      model.updated_at = deserialize_context.request_time
    end
  end

  # Attempting to change created_at is always an error. For a new model, a value
  # is parsed and then completely ignored.
  def deserialize_created_at(value, references:, deserialize_context:)
    value = _deserialize_timestamp('created_at', value)

    if value != self.created_at
      unless new_model?
        raise ViewModel::DeserializationError::ReadOnlyAttribute.new('created_at', blame_reference)
      end
    end
  end

  private

  def _deserialize_timestamp(attr, value)
    ParamSerializers::AccurateTime.load(value)
  rescue IknowParams::Serializer::LoadError => e
    reason = "could not be deserialized because #{e.message}"
    raise ViewModel::DeserializationError::Validation.new(attr, reason, {}, blame_reference)
  end
end
