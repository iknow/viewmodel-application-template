# frozen_string_literal: true

# == Schema Information
#
# Table name: background_job_progresses
#
#  id         :uuid             not null, primary key
#  error_view :jsonb
#  job_class  :string           not null, uniquely indexed => [model_id, model_type]
#  model_type :string           uniquely indexed => [job_class, model_id]
#  owner_type :string           not null
#  progress   :integer          default(0), not null
#  result     :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  model_id   :uuid             uniquely indexed => [job_class, model_type]
#  owner_id   :uuid             not null
#  status_id  :enum             default("waiting"), not null, indexed
#
# Indexes
#
#  background_job_progresses_unique_active_job   (job_class,model_id,model_type) UNIQUE WHERE ((status_id = 'active'::background_job_status) AND (model_id IS NOT NULL))
#  index_background_job_progresses_on_status_id  (status_id)
#
# Foreign Keys
#
#  fk_rails_...  (status_id => background_job_statuses.id)
#
FactoryBot.define do
  factory :background_job_progress do
    owner { build(:user) }
    job_class { 'DummyJob' }
  end
end
