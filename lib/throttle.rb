# frozen_string_literal: true

module Throttle
  class Middleware
    def initialize(app)
      @app = app
    end

    def call(env)
      if (expires = check_throttle(env))
        log_throttled_request(env)
        if ThrottleConfig.dry_run?
          @app.call(env)
        else
          throttled_response(expires)
        end
      else
        @app.call(env)
      end
    end

    private

    def cache
      Cache.instance
    end

    # We decode, verify, and return the authentication JWT from the request
    def token_for(request)
      # FIXME: No authentication is implemented in the app skeleton
      return nil
    end

    def check_throttle(env)
      request = ActionDispatch::Request.new(env)
      path = request.path
      ip = IPAddr.new(request.ip).native
      token = token_for(request)
      uid = token&.fetch('sub', nil)
      type = token&.fetch('type', nil)

      # Whitelist check
      if ThrottleConfig.whitelisted?(path, ip, uid, type)
        env['throttle.whitelisted'] = true
        return nil
      end

      # Rate limit check
      ruleset = ThrottleConfig.ruleset_for(path, ip, uid, type)
      discriminator = uid ? "uid:#{uid}@#{ip}" : "ip:#{ip}"
      discriminator += ";ruleset:#{ruleset}" if ruleset
      expires = cache.read(discriminator)

      env['throttle.discriminator'] = discriminator
      env['throttle.authenticated'] = uid.present?
      env['throttle.ruleset']       = ruleset
      env['throttle.throttled']     = expires.present?

      return expires

    rescue StandardError => e
      # In case of anything unexpected, make sure Subscriber won't be called
      env['throttle.discriminator'] = nil
      Rails.logger.error "Unexpected error in Throttle middleware: #{e}"
      Honeybadger.notify(e)
      return nil
    end

    def throttled_response(expires)
      retry_after = expires.to_i - Time.now.utc.to_i + 1
      headers = { 'content-type' => 'application/json', 'retry-after' => retry_after.to_s }
      response =  { error: { status: 429, detail: 'Rate limit exceeded', retry_after: } }
      [429, headers, [JSON.generate(response)]]
    end

    def log_throttled_request(env)
      discriminator = env['throttle.discriminator']
      method = env['REQUEST_METHOD']
      path = env['PATH_INFO']
      dry_run = ThrottleConfig.dry_run? ? ' [DRY RUN]' : ''
      Rails.logger.info "Throttled request: #{method} #{path} client: #{discriminator}#{dry_run}"
    end
  end

  class Subscriber < ActiveSupport::Subscriber
    attach_to :action_controller

    def process_action(event)
      request = event.payload[:request]
      env = request.env

      # do not increment count if the request already throttled or whitelisted
      return if env['throttle.throttled'] || env['throttle.whitelisted']

      discriminator = env['throttle.discriminator']
      return if discriminator.nil?

      authenticated = env['throttle.authenticated']
      ruleset       = env['throttle.ruleset']

      authenticated_limits, unauthenticated_limits = ThrottleConfig.limits_for_ruleset(ruleset)
      limits = authenticated ? authenticated_limits : unauthenticated_limits

      return unless limits.enabled

      period = limits.period
      runtime = event.duration
      db_runtime = event.payload[:db_runtime]

      # Using update counters asynchronously
      # This could save us 4 RTT to the cache for each request
      WORKER_POOL.post do
        key, expires_in, expires_ts = key_and_expiry(discriminator, period)
        counters = update_counters(key, expires_in, runtime, db_runtime)
        if limits.limit_exceeded?(counters)
          cache.write(discriminator, expires_ts, expires_in)
          Rails.logger.info "Throttling client: #{discriminator} counters: #{counters} expires: #{expires_ts}"
        end
      end
    end

    private

    WORKER_POOL = Concurrent::ThreadPoolExecutor.new(
      min_threads: 1,
      max_threads: ENV.fetch('RAILS_MAX_THREADS', 5).to_i,
      max_queue: 0,
      fallback_policy: :caller_runs,
    )

    def cache
      Cache.instance
    end

    def update_counters(key, expires_in, runtime_ms, db_runtime_ms)
      requests = cache.count("#{key}:requests", expires_in)
      # we have milliseconds for runtimes, but we want microseconds in counters
      runtime = cache.count_by("#{key}:runtime", expires_in, (runtime_ms * 1000).round)
      db_runtime = cache.count_by("#{key}:db_runtime", expires_in, (db_runtime_ms * 1000).round)
      { requests:, runtime:, db_runtime: }
    end

    def key_and_expiry(unprefixed_key, period)
      last_epoch_time = Time.now.utc.to_i
      expires_in = (period - (last_epoch_time % period) + 1).to_i
      expires_ts = last_epoch_time + expires_in
      ["#{(last_epoch_time / period).to_i}:#{unprefixed_key}", expires_in, expires_ts]
    end
  end

  class Cache
    include Singleton

    class MissingCacheError < StandardError; end

    def initialize
      super
      @store = ::Rails.cache
      @prefix = 'throttle'
      raise MissingCacheError unless @store.present?
    end

    def read(unprefixed_key)
      @store.read("#{@prefix}:#{unprefixed_key}", raw: true)
    end

    def write(unprefixed_key, value, expires_in)
      @store.write("#{@prefix}:#{unprefixed_key}", value, raw: true, expires_in:)
    end

    def count(key, expires_in)
      count_by(key, expires_in, 1)
    end

    def count_by(unprefixed_key, expires_in, value)
      key = "#{@prefix}:#{unprefixed_key}"
      result = @store.increment(key, value, raw: true, expires_in:)
      # Some stores return nil when incrementing uninitialized values
      if result.nil?
        @store.write(key, value, raw: true, expires_in:)
      end
      result || value
    end
  end
end
