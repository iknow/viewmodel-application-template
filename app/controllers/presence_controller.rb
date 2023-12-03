# frozen_string_literal: true

class PresenceController < ApplicationController
  def show
    # Must not touch the Rails session
    request.session_options[:skip] = true
    render(json: { 'data' => { 'time' => Time.now.utc.iso8601(3) } })
  end
end
