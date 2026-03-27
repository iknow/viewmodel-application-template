# frozen_string_literal: true

class ApplicationAccessControl < ViewModel::AccessControl::Tree
  # All ApplicationAccessControl subclasses inherit rules from their superclass(es)
  class << self
    def inherited(subclass)
      super
      subclass.include_from(self)
    end

    # An externally-associated child needs to access control its parent for
    # controlling access to edits of the association itself. For our access
    # control linting, we want to exclude this special associated type from the
    # usual requirement that if you mention a root view, you also must mention
    # all its reachable root dependencies.
    def parent_view(parent_view_name, &)
      (@external_parents ||= []) << parent_view_name
      self.view(parent_view_name, &)
    end

    def external_parent?(parent_view_name)
      @external_parents&.include?(parent_view_name)
    end
  end
end
