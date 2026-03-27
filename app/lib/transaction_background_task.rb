# frozen_string_literal: true

# Tool to enqueue a task to be run concurrently during this transaction. Each
# task is joined before the transaction is committed, and any exceptions
# encountered are re-raised. To avoid potential thread explosion, we use a
# singleton worker pool. This is expected to be used for tasks that
# predominantly block on IO such as network requests: it's not appropriate to
# use it for parallelizing arbitrary computation. Furthermore, as a parallel
# thread it is no longer in the same transaction context: it must not access the
# database.
#
# A worker may optionally return an AfterTransactionRunner to handle its
# finalization in the case of commit/rollback, which will be executed as
# appropriate at the end of the transaction. The returned AfterTransactionRunner
# must not have been added to any transaction. Because a finalizer cannot be
# added to the transaction during the worker's execution, a worker must not
# return exceptionally once a finalizer has been created unless it first handles
# that finalization.
class TransactionBackgroundTask
  include Singleton

  class << self
    delegate :in_background, to: :instance
  end

  def initialize
    threads_count = ENV.fetch('RAILS_MAX_THREADS', 5).to_i * 2
    @worker_pool = Concurrent::ThreadPoolExecutor.new(
      min_threads: threads_count,
      max_threads: threads_count,
      max_queue: 0,
      fallback_policy: :caller_runs,
    )
  end

  class TransactionJoiner
    include ViewModel::AfterTransactionRunner

    def initialize(future)
      @future = future
      @enqueued_finalizers = Set.new
    end

    def before_commit
      # Wait for the future and re-raise any exceptions
      transaction_finalizer = @future.value!

      if transaction_finalizer
        # We don't yet know if the commit will succeed: add the finalizer to the
        # current transaction to handle after commit/rollback.
        transaction_finalizer.before_commit
        transaction_finalizer.add_to_transaction
        @enqueued_finalizers << transaction_finalizer
      end
    end

    def after_rollback
      unless @future.cancel
        # Wait for completion, ignoring any exceptions
        transaction_finalizer = @future.value

        if transaction_finalizer && !@enqueued_finalizers.include?(transaction_finalizer)
          # We know that the commit failed: we must perform the rollback action
          # unless it has already been enqueued by our before_commit.
          transaction_finalizer.after_rollback
        end
      end
    end
  end

  def in_background
    if ApplicationRecord.connection.transaction_open?
      future = Concurrent::Future.execute(executor: @worker_pool) { yield(true) }
      TransactionJoiner.new(future).add_to_transaction
      true
    else
      # Without a transaction to bound us, we can't safely background the task:
      # run it inline and handle any finalization tasks immediately.
      finalizer = yield(false)

      if finalizer
        finalizer.before_commit
        finalizer.after_commit
      end

      false
    end
  end
end
