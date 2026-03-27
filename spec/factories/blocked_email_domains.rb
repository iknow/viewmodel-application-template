# frozen_string_literal: true

# == Schema Information
#
# Table name: blocked_email_domains
#
#  id         :uuid             not null, primary key
#  automatic  :boolean          default(FALSE), not null
#  name       :string           not null, uniquely indexed
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_blocked_email_domains_on_name  (name) UNIQUE
#
FactoryBot.define do
  factory :blocked_email_domain do
    name { 'guerillamail.com' }
  end
end
