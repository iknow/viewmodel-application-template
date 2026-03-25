# frozen_string_literal: true

class BackgroundJobProgressView < ApplicationView
  self.schema_version = 3
  root!

  attribute :job_class
  attribute :model_id
  attribute :model_type
  attribute :status, format: ParamSerializers::BackgroundJobStatus

  association :owner, viewmodels: [UserView]

  attribute :progress
  attribute :result
  attribute :error_view

  include ConstrainedTimestamps
  timestamp_attributes

  migrates from: 1, to: 2 do
    down do |view, _refs|
      view['result'] = JSON.dump(view['result'])
    end
    up { |_, _| }
  end

  migrates from: 2, to: 3 do
    down do |view, _refs|
      error_view = view.delete('error_view')
      view['error_views'] =
        if error_view.nil?
          nil
        else
          [error_view]
        end
    end
    up { |_, _| }
  end
end
