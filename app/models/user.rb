# frozen_string_literal: true

# == Schema Information
#
# Table name: users
#
#  id                    :uuid             not null, primary key
#  email                 :string           not null
#  interface_language_id :enum             not null, indexed
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#
# Indexes
#
#  index_users_on_interface_language_id  (interface_language_id)
#
# Foreign Keys
#
#  fk_rails_...  (interface_language_id => languages.id)
#
class User < ApplicationRecord
  belongs_to_enum :interface_language, class_name: 'Language'

  # FIXME: the minimal demo has no model of user permissions
  def effective_permissions
    []
  end
end
