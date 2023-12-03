# frozen_string_literal: true

require 'middleware/json_error_handler'
require 'middleware/multipart_upload'

Rails.application.config.middleware.use Middleware::JsonErrorHandler
Rails.application.config.middleware.use Middleware::MultipartUpload
