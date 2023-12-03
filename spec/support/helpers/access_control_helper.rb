# frozen_string_literal: true

module AccessControlHelper
  extend RSpec::Matchers::DSL
  extend ActiveSupport::Concern

  def new_serialize_context
    subject.class.new_serialize_context(request_context:,
                                        access_control: self.access_control.new)
  end

  def new_deserialize_context
    subject.class.new_deserialize_context(request_context:,
                                          access_control: self.access_control.new)
  end

  def request_context
    RequestContext.with(
      permissions:,
      resource_owner:,
      ip: '1.1.1.1')
  end

  def resource_owner
    nil
  end

  def permissions
    if resource_owner
      resource_owner.effective_permissions
    end
  end

  def doorkeeper_token
    if resource_owner
      create(:doorkeeper_access_token, resource_owner:, abilities: permissions.referenced_abilities)
    end
  end

  def serialize_results
    AccessControlVisitor.new(subject, new_serialize_context)
  end

  def deserialize_results(*edits)
    AccessControlVisitor.new(subject, new_deserialize_context, *edits)
  end

  def change(id, new: false, attrs: [], assocs: [], deleted: false)
    changes = ViewModel::Changes.new(
      new:,
      changed_attributes:   Array.wrap(attrs),
      changed_associations: Array.wrap(assocs),
      deleted:)

    AccessControlVisitor::EntityChange.new(id, changes)
  end

  # Private/internal predicate for accurately matching viewmodel errors
  #   :type            - either :view_failure, or :edit_failure (passed directly through)
  #   :viewmodel       - viewmodel against which the error must be reported
  #   :exception_type  - exception class predicate (match any if nil)
  #   :message_matcher - exception message predicate (match any if nil)
  FailureMatcher = Struct.new(:type, :viewmodel, :exception_type, :message_matcher) do
    def initialize(type, viewmodel, exception_type, message_matcher)
      super
      if message_matcher && exception_type.nil?
        raise ArgumentError.new('Cannot match exception message without exception type critera')
      end
    end

    def describe
      case
      when message_matcher && exception_type
        "expected #{type} of type #{exception_type} with message matching #{message_matcher}}"
      when exception_type
        "expected #{type} of type #{exception_type}"
      else
        "expected #{type}"
      end
    end

    def error_for_target(visitor)
      visitor.public_send(self.type, self.viewmodel)
    end

    def matches?(error)
      type_matches?(error) && message_matches?(error)
    end

    def type_matches?(error)
      exception_type.nil? || error.is_a?(exception_type)
    end

    def message_matches?(error)
      message_matcher.nil? || message_matcher.match(error.message)
    end
  end

  # Example usage:
  #   expect(deserialize_results(change(foo))).to be_rejected_by(view_failure(foo))

  def view_failure(viewmodel, error_type = nil, message_matcher = nil)
    FailureMatcher.new(:view_failure, viewmodel, error_type, message_matcher)
  end

  def edit_failure(viewmodel, error_type = nil, message_matcher = nil)
    FailureMatcher.new(:edit_failure, viewmodel, error_type, message_matcher)
  end

  def format_access_control_errors(errors_by_viewmodel)
    if errors_by_viewmodel.blank?
      "\tnone"
    else
      errors_by_viewmodel.map do |viewmodel, error|
        format_access_control_error(viewmodel, error)
      end.join('\n')
    end
  end

  def format_access_control_error(viewmodel, error)
    if error.nil?
      "\t#{error.inspect}"
    else
      "\t#{viewmodel.to_reference}:\n\t\t#{error.class}\n\t\t'#{error.message}'"
    end
  end

  matcher(:be_rejected_by) do |matcher|
    match do |visitor|
      if (error = matcher.error_for_target(visitor))
        matcher.matches?(error)
      end
    end

    failure_message do |visitor|
      error = matcher.error_for_target(visitor)
      but   = case
              when error.nil?
                "no error was raised for the given viewmodel #{matcher.viewmodel.to_reference}"
              else
                "the raised error didn't match the critera"
              end

      [
        "#{matcher.describe}, but #{but}",
        'viewmodel failure:',
        format_access_control_error(matcher.viewmodel, error),
        'all view failures:',
        format_access_control_errors(visitor.all_view_failures),
        'all edit failures:',
        format_access_control_errors(visitor.all_edit_failures),
      ].join("\n")
    end
  end

  matcher(:be_permitted) do
    match do |visitor|
      visitor.permitted?
    end

    failure_message do |visitor|
      [
        'expected action to be permitted, but encountered errors',
        'all view failures:',
        format_access_control_errors(visitor.all_view_failures),
        'all edit failures:',
        format_access_control_errors(visitor.all_edit_failures),
      ].join("\n")
    end
  end

  # Traverse a ViewModel's tree, applying callbacks (i.e. access control) to the
  # specified traversal context and collecting any access control errors. All
  # nodes are visited for serialization and deserialization. Nodes provided in
  # `entity_changes` are additionally visited for OnChange with the specified
  # changes.
  class AccessControlVisitor < ViewModel::ActiveRecord::Visitor
    EntityChange = Struct.new(:id, :change)

    def initialize(viewmodel, context, *entity_changes)
      super(for_edit: context.is_a?(ViewModel::DeserializeContext))

      @edits = entity_changes.map(&:to_a).to_h
      @edits_seen    = []
      @view_failures = {}
      @edit_failures = {}

      visit(viewmodel, context:)
      if (missing_edits = @edits.keys - @edits_seen).present?
        raise "Invalid test: did not visit edit node(s) '#{missing_edits}'"
      end
    end

    def permitted?
      @view_failures.blank? && @edit_failures.blank?
    end

    def view_failure(viewmodel)
      @view_failures[viewmodel]
    end

    def edit_failure(viewmodel)
      @edit_failures[viewmodel]
    end

    def all_view_failures
      @view_failures
    end

    def all_edit_failures
      @edit_failures
    end

    # Provide changes to callback hooks
    def changes(view)
      id = view.id
      @edits_seen << id
      @edits[id] || super
    end

    # Override `run_callback` to catch and record AccessControl errors
    def run_callback(hook, view, context:,  **args)
      super
    rescue ViewModel::AccessControlError => ex
      errors = hook_errors(hook)
      if errors.nil?
        raise "Invalid test: caught error from unexpected hook #{hook.name}"
      end

      errors[view] = ex
    end

    def hook_errors(hook)
      case hook
      when ViewModel::Callbacks::Hook::BeforeVisit then @view_failures
      when ViewModel::Callbacks::Hook::OnChange    then @edit_failures
      else nil
      end
    end
  end
end
