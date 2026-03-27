# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ElasticsearchImportJob do
  include UseActiveJobTestHelper
  let(:subject) { ElasticsearchImportJob }

  context 'with stubbed import failures' do
    before do
      stub_const('ElasticsearchImportJob::NOTIFY_AFTER_RETRIES', 1)
      expect(BlockedEmailDomainsIndex).to receive(:import_with_lock).exactly(2).times.and_raise(Faraday::ConnectionFailed, 'no')
      expect(BlockedEmailDomainsIndex).to receive(:import_with_lock).once.and_return(true)
    end

    it 'notifies on retry' do
      assert_enqueued_jobs 1 do
        subject.perform_later(BlockedEmailDomainsIndex.name, [SecureRandom.uuid])
      end

      # Fail without notify, fail with notify, success
      expect(Honeybadger).to receive(:notify).once

      assert_performed_jobs 3 do
        perform_enqueued_jobs
      end
    end
  end
end
