# frozen_string_literal: true

# == Schema Information
#
# Table name: background_job_progresses
#
#  id         :uuid             not null, primary key
#  job_class  :string           not null, indexed => [model_id, model_type]
#  model_id   :uuid             indexed => [job_class, model_type]
#  model_type :string           indexed => [job_class, model_id]
#  owner_id   :uuid             not null
#  owner_type :string           not null
#  status_id  :enum             default("waiting"), not null, indexed
#  progress   :integer          default(0), not null
#  result     :jsonb
#  error_view :jsonb
#  created_at :datetime         not null
#  updated_at :datetime         not null
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
