# frozen_string_literal: true

# HoneybadgerThrottledError implements a reverse throttle for exception
# reporting: some exceptions (such as transient network errors) we expect to
# happen regularly, but we only want to know about then if they happen more
# often than a certain threshold. HoneybadgerThrottledError uses the same
# counting cache infrastructure as request throttling to suppress notification
# until the threshold is exceeded.
module HoneybadgerThrottledError
  extend ActiveSupport::Concern

  class_methods do
    attr_accessor :throttle_limit, :throttle_period

    # Reuse the same cache infrastructure as request throttling
    def cache
      Throttle::Cache.instance
    end
  end

  def should_report!
    # Always report if unconfigured
    return true if self.class.throttle_limit.nil? || self.class.throttle_period.nil?

    error_name =
      if self.is_a?(MaskingServiceError)
        honeybadger_error_class.name
      else
        self.class.name
      end

    discriminator = "error:#{error_name}"
    key, expires_in, @throttled_error_expires_ts = key_and_expiry(discriminator, self.class.throttle_period.to_i)

    @throttled_error_count = self.class.cache.count(key, expires_in)
    @throttled_error_count >= self.class.throttle_limit
  end

  def throttled_exception_details
    {
      count: @throttled_error_count || 0,
      limit: self.class.throttle_limit,
      period: self.class.throttle_period,
      expiry: @throttled_error_expires_ts,
    }
  end

  def to_honeybadger_context
    context = defined?(super) ? super : {}
    context.merge(
      throttled_error: throttled_exception_details,
    )
  end

  private

  def key_and_expiry(unprefixed_key, period)
    last_epoch_time = Time.now.utc.to_i
    expires_in = (period - (last_epoch_time % period) + 1).to_i
    expires_ts = last_epoch_time + expires_in
    ["#{(last_epoch_time / period).to_i}:#{unprefixed_key}", expires_in, expires_ts]
  end
end
