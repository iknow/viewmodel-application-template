class AddAbilities < ActiveRecord::Migration[7.0]
  include ActsAsEnumHelper
  def change
    create_acts_as_enum :abilities
  end
end
