# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL
      CREATE EXTENSION "uuid-ossp"
    SQL

    create_table :users, id: :uuid, default: 'uuid_generate_v1mc()' do |t|
      t.string :email, unique: true, null: false
      t.column :interface_language_id, :language, null: false, index: true
      t.foreign_key :languages, column: :interface_language_id
      t.timestamps
    end
  end
end
