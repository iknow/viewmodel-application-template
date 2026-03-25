# frozen_string_literal: true

require 'renum_serializer'
require 'timezone_serializer'
require 'uploaded_file_serializer'

Rails.application.config.active_job.custom_serializers << RenumSerializer
Rails.application.config.active_job.custom_serializers << TimezoneSerializer
Rails.application.config.active_job.custom_serializers << UploadedFileSerializer
