# frozen_string_literal: true

# == Schema Information
#
# Table name: blocked_email_domains
#
#  id         :uuid             not null, primary key
#  name       :string           not null, indexed
#  automatic  :boolean          default(FALSE), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_blocked_email_domains_on_name  (name) UNIQUE
#

class BlockedEmailDomain < ApplicationRecord
  validates_all_not_null_columns!
  validates_all_string_columns!

  before_save :downcase_domain

  def downcase_domain
    self.name = self.name.downcase
  end
end
