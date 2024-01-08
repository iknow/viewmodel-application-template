# frozen_string_literal: true

# Staging environment should be identical to production in everything except
# external resource configuration.
require_relative './production.rb'

# We'd like to show mailer previews on branch servers, which requires FactoryBot
# to construct fake data.
require 'factory_bot'

Rails.application.config.action_mailer.show_previews = true

Rails.application.config.after_initialize do
  FactoryBot.find_definitions
end
