class AddInterfaceLanguages < ActiveRecord::Migration[7.0]
  include ActsAsEnumHelper
  def change
    create_acts_as_enum :languages, name_attr: :code, initial_members: [:en] do |t|
      t.string :name
      t.boolean :ideographic
    end
  end
end
