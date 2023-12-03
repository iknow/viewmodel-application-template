# frozen_string_literal: true

# We want to support uploading files along with viewmodel request using
# multipart MIME. If we detect this kind of upload, we want to:
# * parse the root JSON body into parameters as our main request
# * Separate MIME uploaded files and move them into a specially named request parameter
#
# We allow two formats:
# * multipart/related with a root type of application/json; and
# * multipart/form-data including an application/json body with the
#   content-disposition name parameter 'viewmodel-json-root'.
#
# To support Rack's idiosyncracies, we have two non-standard requirements:
# * multipart/related uploads MUST name the root object using the 'start'
#   parameter, even if it's the first body part. This is because Rack doesn't
#   differentiate mime parts by order.
# * file upload body parts MUST specify a 'filename' content-disposition
#   parameter. The value of this will not be used, but is required for Rack to
#   treat the data as an uploaded file.
class Middleware::MultipartUpload
  UPLOADED_FILES_PARAM = '__multipart_uploads'
  FORM_ROOT_CID        = 'viewmodel-json-root'

  class MissingRoot < ViewModel::Error
    status 400
    code 'MultiPartUpload.MissingRootPart'
    detail 'MIME multipart upload missing root body'
  end

  class NonFileUpload < ViewModel::Error
    status 400
    code 'MultiPartUpload.InvalidFileUpload'

    def initialize(cid)
      super()

      @cid = cid
    end

    def detail
      "MIME multipart file upload missing Content-Disposition filename: #{@cid}"
    end

    def meta
      { cid: @cid }
    end
  end

  def initialize(app)
    @app = app
  end

  def call(env)
    if env['rack.input']
      begin
        extract_multipart_upload(env)
      rescue MissingRoot, NonFileUpload, Middleware::JsonErrorHandler::ParseError => e
        env['rack.viewmodel.error'] = e
        return Api::ApplicationController.action(:render_error_from_middleware).call(env)
      end
    end

    @app.call(env)
  end

  private

  def extract_multipart_upload(env)
    type, *type_params = env['CONTENT_TYPE']&.split(/; */)
    type_params = type_params.to_h do |p|
      k, v = p.split('=', 2)
      next k, v
    end

    # The env['rack.request.form_hash'] is created as a side-effect of calling
    # Rack::Request#POST, which--if not called by an earlier middleware such as
    # Rack::MethodOverride--will be later performed by ActionDispatch::Request
    # in the Rails application as part of its own parameter parsing.
    # Rack::MethodOverride will only do it for us in the case of post requests,
    # and we need it: call it directly.
    unless env.has_key?('rack.request.form_hash')
      Rack::Request.new(env).POST
    end

    params = env['rack.request.form_hash'] || {}
    params = preprocess_params(params)

    if type == 'multipart/related' && type_params['type'] == 'application/json'
      root_body_id = type_params['start']
      raise MissingRoot.new unless root_body_id

      env['rack.request.form_hash'] = swizzle_bodies(params, root_body_id)

    elsif type == 'multipart/form-data' && params.has_key?(FORM_ROOT_CID)
      env['rack.request.form_hash'] = swizzle_bodies(params, FORM_ROOT_CID)
    end
  end

  # Each MIME body may be identified either by a Content-ID header or a
  # Content-Disposition 'name' parameter. In the case of the former, Rack
  # doesn't strip off the angle braces. We want to do this ourselves so we can
  # match cid: urls without the angle braces (RFC2392).
  CID_REGEX = /\A<(.*)>\Z/.freeze
  def preprocess_params(params)
    params.each_with_object({}) do |(key, value), ps|
      if (match = CID_REGEX.match(key)) && key == extract_content_id(value)
        key = value[:name] = match[1]
      end

      ps[key] = value
    end
  end

  def extract_content_id(upload_param)
    if upload_param.is_a?(Hash) && (headers = upload_param[:head])
      headers.split("\r\n").each do |h|
        k, v = h.split(': ', 2)
        return v if k.downcase == 'content-id'
      end
    end

    nil
  end

  def swizzle_bodies(params, root_body_id)
    root_body = params.delete(root_body_id)
    raise MissingRoot.new unless root_body

    params.each do |key, value|
      unless value.is_a?(Hash)
        raise NonFileUpload.new(key)
      end
    end

    json_body =
      case root_body
      when Hash
        # ensure content type
        file = root_body[:tempfile]
        file.rewind
        file.read
      when String
        root_body
      end

    parsed_root =
      begin
        ActiveSupport::JSON.decode(json_body)
      rescue ActiveSupport::JSON.parse_error => e
        raise Middleware::JsonErrorHandler::ParseError.new(e.message)
      end

    parsed_root[UPLOADED_FILES_PARAM] = params

    parsed_root
  end
end
