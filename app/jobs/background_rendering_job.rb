# frozen_string_literal: true

# Runs a controller action in the background using
# ActionDispatch::Integration::Session, and records its result onto a
# BackgroundJobProgress.
class BackgroundRenderingJob < BackgroundJobProgressJob
  queue_as :backgrounded_requests

  PER_OWNER_LIMIT = 3
  DATABASE_TIMEOUT = 1.minute

  class TooManyJobs < ServiceError
    status 429
    code 'BackgroundRendering.TooManyJobs'
    detail "Too many background rendering tasks for the current user (#{PER_OWNER_LIMIT}), try again later"
  end

  class BackgroundRenderFailure < ServiceError
    def initialize(response)
      @status = response.status
      @content_type = response.content_type
      @body = response.body
      super()
    end

    status 500
    code 'BackgroundRendering.UnexpectedResult'
    detail 'Encountered an unexpected result while rendering the backgrounded request'

    def meta
      {
        status: @status,
        body: @body,
        content_type: @content_type,
      }
    end
  end

  def perform_background_task(job_progress, host:, remote_addr:, https:, method:, path:, params:, headers:)
    session = ActionDispatch::Integration::Session.new(Rails.application)

    session.host = host
    session.remote_addr = remote_addr
    session.https! if https

    env = {
      BackgroundRendering::BACKGROUNDED_REQUEST => true,
      BackgroundRendering::BACKGROUND_JOB_PROGRESS => job_progress,
    }.merge(Rails.application.env_config)

    session_args = { params:, headers:, env: }

    # Encode POST and PUT params as JSON bodies. The
    # ActionDispatch::Integration::Session doesn't handle this for GETs: this
    # means that backgrounding a request that specified its params in a GET
    # request body is lossy, as the params will all be coerced to Strings.
    session_args[:as] = :json if [:post, :put].include?(method)

    DatabaseTimeout.with_timeout(DATABASE_TIMEOUT.in_milliseconds) do
      DisableActiveSupportExecutorReset.without_reset do
        session.process(method, path, **session_args)
      end
    end

    response = session.response
    body = response.body

    content_type =
      if response.content_type
        begin
          ContentType.parse(response.content_type).type
        rescue ContentType::InvalidContentType
          raise BackgroundRenderFailure.new(response)
        end
      end

    if content_type == 'application/json'
      begin
        body = ActiveSupport::JSON.decode(response.body)
      rescue JSON::ParserError
        raise BackgroundRenderFailure.new(response)
      end
    elsif body == ''
      # BackgroundJobProgressJob convention is to return nil rather than empty
      # string for no response
      body = nil
    end

    if response.successful?
      BackgroundJobProgressJob::Result.success(body)
    elsif body.is_a?(Hash) && body.has_key?('error')
      BackgroundJobProgressJob::Result.failure(body['error'])
    else
      raise BackgroundRenderFailure.new(response)
    end
  rescue BackgroundRenderFailure => e
    view = self.class.render_error(e)
    BackgroundJobProgressJob::Result.failure(view)
  end
end
