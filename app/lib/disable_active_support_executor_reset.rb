# frozen_string_literal: true

# When a background job is being being called from GoodJob, we're already nested
# in a legitimate Rails executor, which hasn't been lost or discarded: its
# cleanup will be called when we return to it. We must not allow it to be simply
# `reset` away in the ActionDispatch::Executor middleware that will be invoked
# when we re-enter the Rails Rack appliction, because that would would clean the
# current executor context up early, and cause it to be double-freed once we
# return to GoodJob.
module DisableActiveSupportExecutorReset
  KEY = :disable_active_support_executor_reset

  def run!(reset: false)
    reset = false if Thread.current[KEY]
    super(reset:)
  end

  def self.without_reset(&)
    Thread.current[KEY] = true
    yield
  ensure
    Thread.current[KEY] = nil
  end
end

ActiveSupport::ExecutionWrapper.singleton_class.prepend(DisableActiveSupportExecutorReset)
