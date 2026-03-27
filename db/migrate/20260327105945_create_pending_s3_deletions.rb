# frozen_string_literal: true

class CreatePendingS3Deletions < ActiveRecord::Migration[7.0]
  def change
    create_table :pending_s3_deletions, id: :uuid do |t|
      t.string :region, null: false
      t.string :bucket_name, null: false
      t.string :path, null: false
      t.string :reason
      t.boolean :dead, null: false, default: false
      t.integer :retry_count, null: false, default: 0

      t.timestamps
    end

    add_index :pending_s3_deletions, :updated_at,
              where: 'NOT dead'
  end
end
