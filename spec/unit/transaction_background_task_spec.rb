# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'TransactionBackgroundTask' do
  class TaskFailure < RuntimeError; end
  class HookFailure < RuntimeError; end

  class Finalizer
    include ViewModel::AfterTransactionRunner
  end

  # Disable transaction wrappers to observe transaction hooks directly
  before(:all) do
    self.use_transactional_tests = false
  end

  after(:all) do
    self.use_transactional_tests = true
  end

  context 'with a successful task' do
    let(:object) { double('object') }

    def task
      object.invoke
      nil
    end

    it 'invokes the background task' do
      expect(object).to receive(:invoke)

      ApplicationRecord.transaction do
        TransactionBackgroundTask.in_background { task }
      end
    end

    context 'outside a transaction' do
      before do
        expect_any_instance_of(Concurrent::Future).not_to receive(:execute)
      end

      it 'runs it directly' do
        expect(object).to receive(:invoke)
        TransactionBackgroundTask.in_background { task }
      end
    end
  end

  context 'with a failed task' do
    def task
      raise TaskFailure.new
    end

    it 'reraises the failure' do
      expect {
        ApplicationRecord.transaction do
          TransactionBackgroundTask.in_background { task }
        end
      }.to raise_error(TaskFailure)
    end

    context 'outside a transaction' do
      before do
        expect_any_instance_of(Concurrent::Future).not_to receive(:execute)
      end

      it 'raises the failure' do
        expect {
          TransactionBackgroundTask.in_background { task }
        }.to raise_error(TaskFailure)
      end
    end
  end

  context 'with a transaction finalizer' do
    let(:finalizer) { Finalizer.new }

    def task
      finalizer
    end

    context 'on success' do
      it 'calls the commit hooks' do
        expect(finalizer).to receive(:before_commit)
        expect(finalizer).to receive(:after_commit)

        ApplicationRecord.transaction do
          TransactionBackgroundTask.in_background { task }
        end
      end

      context 'outside a transaction' do
        it 'calls the commit hooks' do
          expect(finalizer).to receive(:before_commit)
          expect(finalizer).to receive(:after_commit)

          TransactionBackgroundTask.in_background { task }
        end
      end
    end

    context 'on transaction failure' do
      # We try to cancel tasks on rollback so we don't waste any effort. This
      # event lets us pause the test until the task has started and thus can no
      # longer be cancelled.
      let(:task_started) { Concurrent::Event.new }

      def task
        task_started.set
        super
      end

      it 'calls the rollback hooks' do
        expect(finalizer).to receive(:after_rollback)
        ApplicationRecord.transaction do
          TransactionBackgroundTask.in_background { task }
          task_started.wait # give the worker a chance to launch
          raise ActiveRecord::Rollback.new
        end
      end

      context 'with a before_commit hook failure' do
        let(:failure_hook) do
          hook = Finalizer.new
          expect(hook).to receive(:before_commit) { raise HookFailure.new }
          hook
        end

        context 'preceding it' do
          it 'calls the rollback hook' do
            expect(finalizer).not_to receive(:before_commit)
            expect(finalizer).to receive(:after_rollback)

            expect {
              ApplicationRecord.transaction do
                failure_hook.add_to_transaction
                TransactionBackgroundTask.in_background { task }
                task_started.wait # give the worker a chance to launch
              end
            }.to raise_error(HookFailure)
          end
        end

        context 'following it' do
          it 'calls the before_commit and rollback hooks' do
            expect(finalizer).to receive(:before_commit)
            expect(finalizer).to receive(:after_rollback)

            expect {
              ApplicationRecord.transaction do
                TransactionBackgroundTask.in_background { task }
                failure_hook.add_to_transaction
                task_started.wait # give the worker a chance to launch
              end
            }.to raise_error(HookFailure)
          end
        end
      end
    end
  end
end
