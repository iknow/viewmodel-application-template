# frozen_string_literal: true

# == Schema Information
#
# Table name: background_job_statuses
#
#  id   :enum             not null, primary key
#  name :string           not null, indexed
#
# Indexes
#
#  index_background_job_statuses_on_name  (name) UNIQUE
#
class BackgroundJobStatus < ApplicationRecord
  acts_as_sql_enum do
    waiting
    active
    complete
    failed
  end
end
