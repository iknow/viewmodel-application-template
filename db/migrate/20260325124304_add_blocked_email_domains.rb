class AddBlockedEmailDomains < ActiveRecord::Migration[7.1]
  def change
    create_table :blocked_email_domains, id: :uuid, default: 'uuid_generate_v1mc()' do |t|
      t.string :name, null: false, index: { unique: true }
      t.boolean :automatic, default: false, null: false
      t.timestamps null: false
    end
  end
end
