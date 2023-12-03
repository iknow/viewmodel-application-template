# frozen_string_literal: true

class Api::ApplicationController < ActionController::API
  class InvalidTokenError < ViewModel::AbstractError
    status 401
    code 'Auth.TokenInvalid'
    detail 'Presented authentication token was not valid.'
  end

  include IknowParams::Parser

  rescue_from StandardError, with: :render_unexpected_exception

  include ViewModel::Controller # Include after base rescue_from
  include ViewModelErrorHandling

  rescue_from ViewModel::AbstractError, with: ->(ex) do
    if !ex.status.is_a?(Numeric) || ex.status >= 500
      context = {}
      if ex.respond_to?(:meta)
        meta = ex.meta
        context.merge!(ex.meta) if meta.is_a?(Hash)
      end

      honeybadger_notify_exception(ex, context:)
    end
    render_error(ex.view, ex.status)
  end

  include Pagination
  include Filtering
  include Searching
  include CachedViewRendering

  rescue_from InvalidTokenError, with: ->(ex) do
    render_exception(ex, status: 401, code: 'Auth.TokenInvalid')
  end

  before_action :disable_rails_session_cookie
  before_action :validate_auth_token
  before_action :set_error_context

  def initialize(...)
    super
    @response_annotations    = {}
    @supplementary_data      = {}
    @supplementary_data_keys = Set.new
  end

  def validate_auth_token
    # FIXME: parse and validate the supplied authentication token
    true
  end

  def current_resource_owner
    # FIXME: authenticate the current user based on the validated auth token.
    # In the minimal demo, the user's email serves as a bearer token
    @current_resource_owner ||=
      begin
        header = request.authorization
        pattern = /^Bearer /
        email = header.gsub(pattern, '') if header&.match(pattern)

        User.find_by!(email:) if email
      end
  end

  def permissions
    # FIXME: the minimal demo has no model for assigning permissions to users
    @permissions ||=
      if current_resource_owner
        Permissions.authenticated(abilities: current_resource_owner.effective_permissions)
      else
        Permissions.unauthenticated
      end
  end

  def uploaded_files
    @uploaded_files ||= request.params.fetch(Middleware::MultipartUpload::UPLOADED_FILES_PARAM, {})
  end

  def request_context
    @request_context ||=
      RequestContext.with(
        permissions:,
        resource_owner: current_resource_owner,
        ip: request.remote_ip,
        uploaded_files:,
      )
  end

  def set_error_context
    if (user = current_resource_owner)
      Honeybadger.context(user_id: user.id)
    end
    Honeybadger.context(permissions: @permissions)
  end

  def authorize_user!
    request_context.authorize_user!
  end

  # Controllers may annotate their responses with arbitrary metadata. Metadata
  # is provided as a (key, view) pair, where view may be a viewmodel or a
  # primitive/hash/array structure.
  def add_response_metadata(key, view)
    key = key.to_s
    if @response_annotations.has_key?(key)
      raise ArgumentError.new("Cannot add metadata key '#{key}': already present")
    end

    @response_annotations[key] = view
  end

  # Controllers may provide additional data to supplement the entities in the
  # `data` response. Supplementary data for each key is provided as a hash of
  # { entity_id => view }, where view may be a viewmodel or a primitive/hash/array
  # structure.
  def add_supplementary_data(key, data)
    key = key.to_s
    unless @supplementary_data_keys.add?(key)
      raise ArgumentError.new("Cannot add supplementary data for key '#{key}': already present")
    end

    data.each do |id, view|
      entity_data = (@supplementary_data[id] ||= {})
      entity_data[key] = view
    end
  end

  def prerender_viewmodel(viewmodel, status: nil, serialize_context: viewmodel.class.try(:new_serialize_context))
    super do |json|
      render_response_metadata(json)
      yield(json) if block_given?
    end
  end

  def prerender_json_view(json_view, json_references: {})
    super do |json|
      render_response_metadata(json)
      yield(json) if block_given?
    end
  end

  def render_unexpected_exception(exception, status: 500, code: nil, honeybadger_opts: {})
    # The rack middleware included from the railtie
    # (Honeybadger::Rack::ErrorNotifier) wraps each request in a
    # `config.with_request` block, which does most of the work filling
    # out our context. It also handles the post-request cleanup.
    honeybadger_notify_exception(exception, honeybadger_opts)
    render_sanitized_exception(exception, status:, code:)
  end

  def honeybadger_notify_exception(exception, opts)
    if exception.is_a?(MaskingServiceError)
      opts = opts.merge(
        message: exception.honeybadger_message,
        error_class: exception.honeybadger_error_class,
        error_name: exception.honeybadger_error_name,
        backtrace: exception.honeybadger_backtrace,
        cause: exception.honeybadger_cause)

      Honeybadger.context(
        client_facing_error: {
          error: exception.class.name,
          message: exception.message,
          location: exception.backtrace.first,
        })
    end

    if exception.is_a?(HoneybadgerThrottledError) && !exception.should_report!
      opts = opts.merge(tags: 'suppress_notification')
    end

    Honeybadger.notify(exception, opts)
  end

  # Allow Rack middleware to use viewmodel error rendering
  def render_error_from_middleware
    error = request.env.fetch('rack.viewmodel.error')
    render_error(error.view, error.status)
  end

  def render_error(error_view, status = 500)
    super

    # Dump the error to the Rails debug log after rendering
    ViewModelLogging.log_rendered_error(error_view, status)
  end

  def merge_scopes(*scopes)
    scopes.inject do |a, b|
      case
      when b.nil?
        a
      when a.nil?
        b
      else
        a.merge(b)
      end
    end
  end

  def not_found!
    head :not_found
  end

  private

  # We don't want any API requests touching the session cookie, unless we opt
  # for local authentication with cookie sessions.
  def disable_rails_session_cookie
    request.session_options[:skip] = true
  end

  def render_response_metadata(json)
    json.meta do
      ViewModel.serialize(@response_annotations, json)

      if @supplementary_data.present?
        json.supplementary do
          ViewModel.serialize(@supplementary_data, json)
        end
      end
    end
  end
end
