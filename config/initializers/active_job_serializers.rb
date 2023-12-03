# frozen_string_literal: true

require 'renum_serializer'

Rails.application.config.active_job.custom_serializers << RenumSerializer
