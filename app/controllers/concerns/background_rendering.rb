# frozen_string_literal: true

module BackgroundRendering
  extend ActiveSupport::Concern

  BACKGROUNDED_REQUEST = 'ec_backgrounded_request'
  BACKGROUND_JOB_PROGRESS = 'ec_background_request_job_progress'

  IGNORED_PARAMS = [
    'async_response', 'controller', 'action', 'route_viewmodel', 'owner-viewmodel', 'association_name',
  ].freeze

  included do
    before_action :handle_background_render
  end

  class_methods do
    def backgroundable_actions
      return [].each unless block_given?
    end

    def backgroundable_action(*actions)
      actions = actions.map(&:to_s)

      m = Module.new
      m.define_method(:backgroundable_actions) do |&b|
        return to_enum(__method__) unless b

        actions.each { |a| b.call(a) }
        super(&b)
      end

      singleton_class.prepend(m)
    end

    def backgroundable?(action_name)
      backgroundable_actions.include?(action_name)
    end
  end

  class NotBackgroundable < ServiceError
    status 400
    code 'Rendering.NotBackgroundable'
    detail 'The requested action may not be invoked asynchronously'
  end

  def handle_background_render
    if backgrounded?
      Honeybadger.context(background_rendering: true)
      return
    end

    async = parse_boolean_param(:async_response, default: false)
    return unless async

    authorize_ability!(Ability::MAKE_BACKGROUND_REQUEST)

    raise NotBackgroundable.new unless self.class.backgroundable?(self.action_name)

    job_progress = BackgroundJobProgress.transaction do
      live_jobs = BackgroundJobProgress.lock.live
                    .where(job_class: BackgroundRenderingJob.name, owner: current_principal)
                    .pluck(:id)

      if live_jobs.size >= BackgroundRenderingJob::PER_OWNER_LIMIT
        raise BackgroundRenderingJob::TooManyJobs.new
      end

      BackgroundJobProgress.create!(job_class: BackgroundRenderingJob.name, owner: current_principal)
    end

    params = request.params.except(*IGNORED_PARAMS).to_h

    http_headers =
      request.headers.to_h
        .select { |k, _| k.start_with? 'HTTP_' }
        .transform_keys { |k| k.sub(/\AHTTP_/, '').split('_').map(&:capitalize).join('-') }

    BackgroundRenderingJob.perform_later(
      job_progress,
      host: request.host,
      remote_addr: request.remote_ip,
      https: request.ssl?,
      method: request.method,
      path: request.path,
      headers: http_headers,
      params:,
    )

    view = BackgroundJobProgressView.new(job_progress)
    serialize_context = new_serialize_context(access_control: ViewModel::AccessControl::ReadOnly.new)
    render_viewmodel(view, serialize_context:)
  end

  def backgrounded?
    request.env[BACKGROUNDED_REQUEST] == true
  end

  def background_job_progress
    request.env.fetch(BACKGROUND_JOB_PROGRESS)
  end

  def update_background_job_progress!(progress)
    return unless backgrounded?

    background_job_progress.update_progress!(progress)
  end
end
