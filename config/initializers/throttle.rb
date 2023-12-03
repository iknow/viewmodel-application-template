# frozen_string_literal: true

require 'throttle'

Rails.application.config.middleware.use Throttle::Middleware
