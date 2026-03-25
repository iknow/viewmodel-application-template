# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DatabaseTimeout do
  describe '.with_timeout' do
    before(:all) do
      self.use_transactional_tests = false
    end

    after(:all) do
      self.use_transactional_tests = true
    end

    let(:conn) { ActiveRecord::Base.connection }

    before(:example) do
      conn.execute('SET SESSION statement_timeout = 10000')
    end

    after(:example) do
      current_timeout = conn.select_value('SHOW statement_timeout')
      expect(current_timeout).to eq('10s')
    end

    it 'allows short statements' do
      expect {
        DatabaseTimeout.with_timeout(100, conn) do
          conn.execute('SELECT 1')
        end
      }.not_to raise_error
    end

    it 'times out a statement' do
      start_time = Time.now.utc
      expect {
        DatabaseTimeout.with_timeout(100, conn) do
          conn.execute('SELECT pg_sleep(10)')
        end
      }.to raise_error(ActiveRecord::QueryCanceled)
      duration = Time.now.utc - start_time
      expect(duration).to be < 1
    end

    it 'times out a statement inside a transaction' do
      start_time = Time.now.utc
      expect {
        conn.transaction do
          DatabaseTimeout.with_timeout(100, conn) do
            conn.execute('SELECT pg_sleep(10)')
          end
        end
      }.to raise_error(ActiveRecord::QueryCanceled)
      duration = Time.now.utc - start_time
      expect(duration).to be < 1
    end

    it 'does not swallow errors inside a transaction' do
      cause_is_undefined_column = having_attributes(cause: an_instance_of(PG::UndefinedColumn))
      error_type = an_instance_of(ActiveRecord::StatementInvalid).and cause_is_undefined_column

      expect {
        conn.transaction do
          DatabaseTimeout.with_timeout(100, conn) do
            conn.execute('SELECT a')
          end
        end
      }.to raise_error(error_type)
    end
  end
end
