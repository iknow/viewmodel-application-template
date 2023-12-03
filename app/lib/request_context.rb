# frozen_string_literal: true

# RequestContexts are provided from controllers to ViewModel operations, and
# wrap information about the request actor and their permissions.
RequestContext = Value.new(:permissions, resource_owner: nil, ip: nil, internal: false, uploaded_files: {})
class RequestContext
  include ActiveModel::Validations

  validates :permissions, type: { is_a: Permissions }
  validates :resource_owner, allow_nil: true, type: { is_a: User }
  validates :ip, allow_nil: true, type: { is_a: String }
  validates :uploaded_files, type: { hash_from: { is_a: String },
                                     to: { is_a: ActionDispatch::Http::UploadedFile } }
  validates :internal, inclusion: { in: [true, false] }

  attr_reader :request_time

  def self.field_names
    members + [:request_time, :principal]
  end

  def initialize(...)
    @request_time = Time.now.utc
    super
  end

  def self.default
    self.with(permissions: Permissions.unauthenticated)
  end

  def self.internal
    self.with(permissions: Permissions.all, internal: true)
  end

  def self.default_for_user(user, **rest)
    self.with(resource_owner: user, permissions: user.effective_permissions, **rest)
  end

  def self.with_ability(*abilities)
    self.with(permissions: Permissions.global(abilities))
  end

  def staff_positions
    resource_owner&.staff_member&.staff_positions || []
  end

  def principal
    resource_owner
  end

  def authorize_user!
    permissions.authorize!
    raise Permissions::MissingUserError.new unless resource_owner.present?
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
