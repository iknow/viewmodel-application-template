# frozen_string_literal: true

ViewModel::Config.configure! do
  show_cause_in_error_view !Rails.env.production?
end
