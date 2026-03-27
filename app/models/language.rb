# frozen_string_literal: true

# == Schema Information
#
# Table name: languages
#
#  id          :enum             not null, primary key
#  code        :string           not null, uniquely indexed
#  ideographic :boolean
#  name        :string
#
# Indexes
#
#  index_languages_on_code  (code) UNIQUE
#

# Supported user interface languages
class Language < ApplicationRecord
  acts_as_sql_enum(name_attr: :code) do
    en(name: 'English')
    ja(name: 'Japanese', ideographic: true)
  end

  # Each language defines a set of scripts that are used for showing
  # transliterations of foreign-language text for speakers of that language --
  # for example, showing a Latin characters name transliterated into kana. Where
  # a language defines multiple transliteration scripts, they're ordered by
  # preference: if a resource features transliterations into multiple of the
  # transliteration_scripts, the first match is considered the 'best' to
  # display.
  def transliteration_scripts
    case code
    when 'ja'
      [Script::HRKT]
    else
      [Script::LATN]
    end
  end
end
