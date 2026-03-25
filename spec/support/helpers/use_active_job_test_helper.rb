# frozen_string_literal: true

module UseActiveJobTestHelper
  extend ActiveSupport::Concern

  include ActiveJob::TestHelper

  def queue_adapter_for_test
    ActiveJob::QueueAdapters::TestAdapter.new
  end
end
