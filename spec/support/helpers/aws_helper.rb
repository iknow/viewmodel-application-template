# frozen_string_literal: true

module AwsHelper
  def stub_aws(responses = aws_response)
    Aws.config[:s3] = {
      stub_responses: responses,
      logger:         nil,
    }

    # Aws::S3::Clients read and store their configuration from Aws.config on
    # instantiation. Because we have long-lived s3 clients (both for the client
    # cache and for the upload inbox) we need to force them to be re-created
    # with the particular stubbing configuration.
    S3Client.clear_client_cache!
    yield

  ensure
    S3Client.clear_client_cache!
    Aws.config[:s3] = {}
  end

  # Override specific requests:
  # aws_response(put_object: 'ServiceError', head_object: {status_code: 404, body: '', headers: {}})
  def aws_response(overrides = {})
    fake_etag = "\"#{SecureRandom.hex(32)}\""
    {
      list_buckets:  { buckets: [] },
      put_object:    { status_code: 200, headers: { 'ETag' => fake_etag }, body: '' },
      head_object:   { status_code: 200, headers: { 'ETag' => fake_etag }, body: '' },
      delete_object: { status_code: 200, headers: {}, body: '' },
    }.merge(overrides)
  end

  # AWS response stubbing that simulates accepting uploads to specific S3
  # paths that can then be re-downloaded returning the same body.
  def simulated_uploads_aws_responses
    uploaded_bodies = {}
    {
      put_object: ->(context) {
        body_stream = context.http_request.body.instance_variable_get(:@io).to_io
        pos = body_stream.pos
        body_stream.rewind
        body = body_stream.read
        body_stream.seek(pos, IO::SEEK_SET)

        key = context.http_request.endpoint
        uploaded_bodies[key] = body
        {
          status_code: 200,
          headers: { 'ETag' => Digest::MD5.hexdigest(body) },
          body: '',
        }
      },
      get_object: ->(context) {
        key = context.http_request.endpoint
        if (body = uploaded_bodies[key])
          etag = Digest::MD5.hexdigest(body)
          length = body.length
          { status_code: 200, headers: { 'ETag' => etag, 'content-length' => length }, body: }
        else
          { status_code: 404, headers: {}, body: '' }
        end
      },
      head_object: ->(context) {
        key = context.http_request.endpoint
        if (body = uploaded_bodies[key])
          etag = Digest::MD5.hexdigest(body)
          length = body.length
          { status_code: 200, headers: { 'ETag' => etag, 'content-length' => length }, body: '' }
        else
          { status_code: 404, headers: {}, body: '' }
        end
      },
    }
  end

  def aws_object_not_found_stub
    { status_code: 404, body: '', headers: {} }
  end
end
