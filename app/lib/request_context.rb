# frozen_string_literal: true

# RequestContexts are provided from controllers to ViewModel operations, and
# wrap information about the request actor and their permissions.
RequestContext = Value.new(:permissions, resource_owner: nil, ip: nil, internal: false, uploaded_files: {}, request_time: Value.lazy { Time.now.utc })
class RequestContext
  include ActiveModel::Validations

  # This unique local address IP (`fd00` prefix) represents an internal request
  # context that wasn't sourced from a web request, such as a cron job. The
  # context must include an IP address in order to permit audit logging.
  INTERNAL_REQUEST_IP = 'fd70:7848:38e5:1::1'

  validates :permissions, type: { is_a: Permissions }
  validates :resource_owner, allow_nil: true, type: { is_a: User }
  validates :ip, allow_nil: true, type: { is_a: String }
  validates :uploaded_files, type: { hash_from: { is_a: String },
                                     to: { is_a: ActionDispatch::Http::UploadedFile } }
  validates :internal, inclusion: { in: [true, false] }

  def self.field_names
    members + [:principal]
  end

  def self.default
    self.with(permissions: Permissions.unauthenticated)
  end

  def self.internal
    self.with(permissions: Permissions.all, ip: INTERNAL_REQUEST_IP, internal: true)
  end

  def self.default_for_user(user, **rest)
    self.with(resource_owner: user, permissions: user.effective_permissions, **rest)
  end

  def self.with_ability(*abilities)
    self.with(permissions: Permissions.global(abilities))
  end

  def internal?
    internal
  end

  def machine_account?
    false
  end

  def machine_account
    nil
  end

  def staff_positions
    resource_owner&.staff_member&.staff_positions || []
  end

  def principal
    resource_owner || machine_account
  end

  def authorize_user!
    permissions.authorize!
    raise Permissions::MissingUserError.new unless resource_owner.present?
  end

  def with_extra_abilities(*abilities)
    permissions = self.permissions.merge(Permissions.global(abilities))
    self.with(permissions:)
  end

  def to_internal
    RequestContext.internal.with(ip:)
  end

  class NoMatchingPrincipal < ViewModel::Error
    status 403
    code 'RequestContext.NoMatchingPrincipal'
    attr_reader :principal_type, :allowed_types

    def initialize(principal_type, allowed_types)
      @principal_type = principal_type
      @allowed_types = allowed_types
      super()
    end

    def detail
      "Current authentication principal (#{principal_type.name}) could not be matched to any of the allowed types: #{allowed_types.map(&:name).inspect}"
    end

    def meta
      super.merge(
        principal_type: principal_type.name,
        allowed_types: allowed_types.map(&:name),
      )
    end
  end

  enum :PrincipalType do
    User(::User)
    MachineAccount(nil) # ::Doorkeeper::Application
    Anonymous()

    attr_reader :model

    def init(model = nil)
      @model = model
    end

    def self.from_model(model)
      values.detect { |v| v.model && v.model == model }
    end
  end

  def primary_principal(*allowed_types)
    primary_principal!(*allowed_types)
  rescue RequestContext::NoMatchingPrincipal
    nil
  end

  def primary_principal!(*allowed_types)
    if self.machine_account
      if allowed_types.include?(PrincipalType::MachineAccount)
        self.machine_account
      else
        raise NoMatchingPrincipal.new(PrincipalType::MachineAccount, allowed_types)
      end
    elsif (user = self.resource_owner)
      if allowed_types.include?(PrincipalType::User)
        user
      else
        raise NoMatchingPrincipal.new(PrincipalType::User, allowed_types)
      end
    else
      if allowed_types.include?(PrincipalType::Anonymous)
        nil
      else
        raise NoMatchingPrincipal.new(PrincipalType::Anonymous, allowed_types)
      end
    end
  end

  # ActiveModel::Validations requires a mutable instance. Validate a mutable
  # clone and yield the errors if present.
  def validate_context
    copy = self.dup
    unless copy.valid?
      yield(copy.errors)
    end
  end
end
