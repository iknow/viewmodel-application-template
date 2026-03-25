class CreateBackgroundJobProgresses < ActiveRecord::Migration[7.0]
  include ActsAsEnumHelper

  def change
    create_acts_as_enum :background_job_statuses, initial_members: [:waiting, :active, :complete, :failed]

    create_table :background_job_progresses, id: :uuid, default: 'uuid_generate_v1mc()' do |t|
      t.string :job_class, null: false

      t.uuid :model_id, null: true
      t.string :model_type, null: true

      t.uuid :owner_id, null: false
      t.string :owner_type, null: false

      t.column :status_id, :background_job_status, index: true, null: false, default: 'waiting'
      t.foreign_key :background_job_statuses, column: :status_id

      t.integer :progress, default: 0, null: false

      t.jsonb :result
      t.jsonb :error_view

      t.timestamps

      t.index [:job_class, :model_id, :model_type],
              unique: true,
              where: "status_id = 'active' AND model_id IS NOT NULL",
              name: 'background_job_progresses_unique_active_job'
    end
  end
end
