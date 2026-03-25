# frozen_string_literal: true

# Validates that a value is present for the given association, whether it's
# been made using an id or an AR model object.
#
# Example:
#   validates :some_association, association_presence: true
#
class AssociationPresenceValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, _value)
    unless record.associated_to?(attribute)
      record.errors.add(attribute, :blank, message: 'must be present')
    end
  end
end
