# frozen_string_literal: true

# == Schema Information
#
# Table name: abilities
#
#  id   :enum             not null, primary key
#  name :string           not null, indexed
#
# Indexes
#
#  index_abilities_on_name  (name) UNIQUE
#
class Ability < ApplicationRecord
  acts_as_sql_enum do
    viewUsers
    editUsers
  end
end
