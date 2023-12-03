# frozen_string_literal: true

class ApplicationAccessControl < ViewModel::AccessControl::Tree
  # All ApplicationAccessControl subclasses inherit rules from their superclass(es)
  def self.inherited(subclass)
    super
    subclass.include_from(self)
  end
end
