# frozen_string_literal: true

module StreamingResponses
  extend ActiveSupport::Concern

  def with_response_stream(filename:, type:, disposition: 'inline', set_headers: nil)
    headers_set = false
    chunk_handler = ->(chunk) do
      unless headers_set
        # Skip ETag generation: it prevents streaming.
        response.headers['Last-Modified'] = Time.now.httpdate
        response.headers['Content-Type'] = type
        response.headers['Content-Disposition'] = ActionDispatch::Http::ContentDisposition.format(disposition:, filename:)
        set_headers.call if set_headers
        headers_set = true
      end

      response.stream.write(chunk)
    end

    yield(chunk_handler)
  rescue ActionController::Live::ClientDisconnected
    # If the client disconnects, there's nothing more for us to do: we're not
    # managing a transaction.
    response.stream.close
  rescue StandardError => e
    raise unless headers_set

    # Because we've started streaming, we can't report this error to the client.
    # Best we can do is log and notify it to Honeybadger. Report all swallowed
    # errors rather than just 500, since they're not exposed otherwise.
    honeybadger_notify_exception(e, context: { reported_to_client: false })

    ViewModelLogging.log_error(e)
  ensure
    response.stream.close if headers_set
  end

  def with_sse_stream
    response.headers['Content-Type'] = 'text/event-stream'
    response.headers['Last-Modified'] = Time.now.httpdate
    sse = ActionController::Live::SSE.new(response.stream, retry: 300, event: 'open')

    final_event, final_result =
      model_class.transaction(requires_new: true) do
        yield(sse)
      # We need to take over even standard error handling, that rather than hitting
      # render_error/render_exception we render the error to the stream and roll back
      rescue ActionController::Live::ClientDisconnected
        # If the client disconnects during the transaction, we treat that as
        # them opting to cancel the current exchange: rollback cleanly.
        sse.close
        raise ActiveRecord::Rollback.new
      rescue StandardError => e
        error_view =
          if e.is_a?(ViewModel::AbstractError)
            e.view
          else
            ViewModel::WrappedExceptionError.new(e, 500, nil).view
          end

        render_sse_error(sse, e, error_view)
        raise ActiveRecord::Rollback.new
      end

    sse.write(final_result, event: final_event) if final_event
  rescue ActionController::Live::ClientDisconnected
    nil
  ensure
    sse&.close
  end

  # Following the same contract as with_sse_stream, only set up streaming if the
  # `stream` request parameter is true.
  def with_optional_sse_stream(&)
    stream = parse_boolean_param(:stream, default: false)
    if stream
      with_sse_stream(&)
    else
      _, result = model_class.transaction { yield(nil) }

      render_json_string(result)
    end
  end

  def render_sse_message_chunk(sse, message_chunk)
    # To minimize repeated data, render minimal JSON rather than a full
    # viewmodel for each chunk
    view = { i: message_chunk.index, c: message_chunk.content }
    prerendered = Oj.dump(view, mode: :strict, indent: 0)
    sse.write(prerendered, event: 'RolePlay.MessageChunk')
  end

  def render_sse_error(sse, error, error_view)
    response = prerender_error_view(error_view)

    sse.write(response, event: ViewModel::ErrorView.view_name)
    sse.close

    # Report unknown or 500-class errors to Honeybadger
    if !error_view.status.is_a?(Numeric) || error_view.status >= 500
      context = { meta: (error_view.meta if error_view.respond_to?(:meta)) }
      honeybadger_notify_exception(error, context:)
    end

    ViewModelLogging.log_rendered_error(error_view, error_view.status)
  end

  def prerender_error_view(error_view)
    encode_jbuilder do |json|
      serialize_context =
        error_view.class.new_serialize_context(access_control: ViewModel::AccessControl::Open.new)

      json.error do
        ViewModel.serialize(error_view, json, serialize_context:)
      end
    end
  end
end
