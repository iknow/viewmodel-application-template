# frozen_string_literal: true

# == Schema Information
#
# Table name: languages
#
#  id          :enum             not null, primary key
#  code        :string           not null, indexed
#  name        :string
#  ideographic :boolean
#
# Indexes
#
#  index_languages_on_code  (code) UNIQUE
#

# Supported user interface languages
class Language < ApplicationRecord
  acts_as_sql_enum(name_attr: :code) do
    en(name: 'English')
  end
end
