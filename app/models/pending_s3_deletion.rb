# frozen_string_literal: true

# == Schema Information
#
# Table name: pending_s3_deletions
#
#  id          :uuid             not null, primary key
#  bucket_name :string           not null
#  dead        :boolean          default(FALSE), not null
#  path        :string           not null
#  reason      :string
#  region      :string           not null
#  retry_count :integer          default(0), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null, indexed
#
# Indexes
#
#  index_pending_s3_deletions_on_updated_at  (updated_at) WHERE (NOT dead)
#
class PendingS3Deletion < ApplicationRecord
end
