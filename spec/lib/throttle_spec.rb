# frozen_string_literal: true

require 'rails_helper'

# Following test are written by Mr.GhatGPT with some minor fixes from Bearice
RSpec.describe Throttle::Middleware do
  let(:app) { ->(env) { [200, env, 'app response'] } }
  let(:middleware) { described_class.new(app) }
  let(:ip) { '127.0.0.1' }
  let(:uid) { '00000000-0000-0000-0000-000000000000' }
  let(:discriminator) { "uid:#{uid}@#{ip}" }
  let(:request) { double('request') }
  let(:cache) { double('cache') }
  let(:env) { { 'REMOTE_ADDR' => ip, 'REQUEST_METHOD' => 'GET', 'PATH_INFO' => '/api/users' } }
  let(:token) { { 'type' => 'user', 'sub' => uid } }
  let(:ruleset) { nil } # No custom ruleset matched

  before do
    allow(middleware).to receive(:cache).and_return(cache)
    allow(middleware).to receive(:token_for).and_return(token)
  end
  describe '#call' do
    context 'when request is throttled and dry_run is false' do
      before do
        allow(middleware).to receive(:check_throttle).and_return(1)
        allow(ThrottleConfig).to receive(:dry_run?).and_return(false)
      end

      it 'returns 429 with appropriate headers' do
        response = middleware.call(env)

        expect(response[0]).to eq(429)
        expect(response[1]['content-type']).to eq('application/json')
        expect(response[1]['retry-after']).to be_present
        expect(response[2][0]).to include('Rate limit exceeded')
      end
    end

    context 'when request is throttled and dry_run is true' do
      before do
        allow(middleware).to receive(:check_throttle).and_return(1)
        allow(ThrottleConfig).to receive(:dry_run?).and_return(true)
      end

      it 'logs the request and calls the app' do
        expect(middleware).to receive(:log_throttled_request).with(anything)
        response = middleware.call(env)

        expect(response[0]).to eq(200)
        expect(response[1]).to eq(env)
        expect(response[2]).to eq('app response')
      end
    end

    context 'when request is not throttled' do
      before do
        # Mock check_throttle method to return false
        allow(middleware).to receive(:check_throttle).and_return(nil)
      end

      it 'calls the app' do
        response = middleware.call(env)

        expect(response[0]).to eq(200)
        expect(response[1]).to eq(env)
        expect(response[2]).to eq('app response')
      end
    end
  end

  describe '#check_throttle' do
    before do
      allow(ActionDispatch::Request).to receive(:new).with(env).and_return(request)
      allow(ThrottleConfig).to receive(:instance).and_return(double({}))
    end

    context 'when request is whitelisted' do
      before do
        allow(ThrottleConfig.instance).to receive(:whitelisted?).and_return(true)
        allow(request).to receive(:path).and_return('/healthcheck')
        allow(request).to receive(:ip).and_return(ip)
      end

      it 'returns nil and sets env["throttle.whitelisted"] to true' do
        expect(middleware.send(:check_throttle, env)).to eq(nil)
        expect(env['throttle.whitelisted']).to eq(true)
      end
    end

    context 'when request is not whitelisted and rate limit not exceeded' do
      before do
        allow(ThrottleConfig.instance).to receive(:whitelisted?).and_return(false)
        allow(ThrottleConfig.instance).to receive(:ruleset_for).and_return(ruleset)
        allow(request).to receive(:path).and_return('/users')
        allow(request).to receive(:ip).and_return(ip)
        allow(cache).to receive(:read).and_return(nil)
      end

      it 'returns nil and does not set any env variables' do
        expect(middleware.send(:check_throttle, env)).to eq(nil)
        expect(env['throttle.whitelisted']).to be_nil
        expect(env['throttle.discriminator']).to eq(discriminator)
        expect(env['throttle.authenticated']).to eq(true)
        expect(env['throttle.ruleset']).to be_nil
        expect(env['throttle.throttled']).to eq(false)
      end

      context 'when the user is unauthenticated' do
        let(:token) { nil }
        let(:discriminator) { "ip:#{ip}" }

        it 'sets discriminated and authenticated in the environment' do
          expect(middleware.send(:check_throttle, env)).to eq(nil)
          expect(env['throttle.discriminator']).to eq(discriminator)
          expect(env['throttle.authenticated']).to eq(false)
        end
      end

      context 'when a custom ruleset is matched' do
        let(:ruleset) { 'special_rules' }
        let(:discriminator) { super() + ";ruleset:#{ruleset}" }

        it 'sets discriminated and authenticated in the environment' do
          expect(middleware.send(:check_throttle, env)).to eq(nil)
          expect(env['throttle.discriminator']).to eq(discriminator)
          expect(env['throttle.ruleset']).to eq(ruleset)
        end
      end
    end

    context 'when rate limit is exceeded' do
      before do
        allow(ThrottleConfig.instance).to receive(:whitelisted?).and_return(false)
        allow(ThrottleConfig.instance).to receive(:ruleset_for).and_return(ruleset)
        allow(request).to receive(:path).and_return('/users')
        allow(request).to receive(:ip).and_return(ip)
        allow(cache).to receive(:read).and_return(Time.now.to_i + 30)
      end

      it 'returns value and sets env variables for rate limit' do
        expect(middleware.send(:check_throttle, env)).to be_within(1).of(Time.now.to_i + 30)
        expect(env['throttle.whitelisted']).to be_nil
        expect(env['throttle.discriminator']).to eq(discriminator)
        expect(env['throttle.authenticated']).to eq(true)
        expect(env['throttle.ruleset']).to be_nil
        expect(env['throttle.throttled']).to eq(true)
      end
    end
  end
end

RSpec.describe Throttle::Subscriber do
  let(:cache) { double('cache') }
  let(:config) { double('config', enabled: true, period: 10, max_requests: 2, max_runtime: 1, max_db_runtime: 1) }

  let(:authenticated) { false }
  let(:ruleset) { nil }
  let(:discriminator) { 'ip:127.0.0.1' }

  before do
    allow(subject).to receive(:cache).and_return(cache)
    allow(Throttle::Subscriber::WORKER_POOL).to receive(:post).and_yield
    allow(Time).to receive(:now).and_return(double('now', utc: 10))
  end

  describe '#process_action' do
    let(:request) {
      double('request', env: {
        'throttle.whitelisted' => false,
        'throttle.throttled' => false,
        'throttle.discriminator' => discriminator,
        'throttle.authenticated' => false,
        'throttle.ruleset' => ruleset,
      })
    }
    let(:event) { double('event', duration: 0.5, payload: { request:, db_runtime: 0.1 }) }

    context 'when throttling is not enabled for the discriminator' do
      before do
        allow(cache).to receive(:last_epoch_time).and_return(0)
        allow(ThrottleConfig).to receive(:limits_for_ruleset)
                                   .with(nil)
                                   .and_return([double('config'), double('config', enabled: false)])
      end

      it 'does not increment the counter' do
        expect(cache).not_to receive(:write)
        subject.process_action(event)
      end
    end

    context 'when the request is whitelisted' do
      before {
        allow(request.env).to receive(:[])
        allow(request.env).to receive(:[]).with('throttle.whitelisted').and_return(true)
      }

      it 'does not increment the counter' do
        expect(cache).not_to receive(:count)
        subject.process_action(event)
      end
    end

    context 'when the request is already throttled' do
      before {
        allow(request.env).to receive(:[])
        allow(request.env).to receive(:[]).with('throttle.throttled').and_return(true)
      }

      it 'does not increment the counter' do
        expect(cache).not_to receive(:count)
        subject.process_action(event)
      end
    end

    context 'when throttling is enabled for the discriminator' do
      before do
        allow(ThrottleConfig).to receive(:limits_for_ruleset)
                                   .with(ruleset)
                                   .and_return([double('config'), config])
      end

      context 'when the counter has not exceeded the limit' do
        before do
          allow(config).to receive(:limit_exceeded?).and_return(false)
        end

        shared_examples 'increments the counter' do
          it 'increments the counter' do
            expect(cache).not_to receive(:write)
            expect(cache).to receive(:count).with("1:#{discriminator}:requests", 11).and_return(1)
            expect(cache).to receive(:count_by).with("1:#{discriminator}:runtime", anything, anything).and_return(1)
            expect(cache).to receive(:count_by).with("1:#{discriminator}:db_runtime", anything, anything).and_return(1)
            subject.process_action(event)
          end
        end

        include_examples 'increments the counter'

        context 'with a custom ruleset' do
          let(:ruleset) { 'custom-rules' }
          let(:discriminator) { 'ip:127.0.0.1;ruleset:custom-rules' }
          include_examples 'increments the counter'
        end
      end

      context 'when the counter has exceeded the limit' do
        before do
          allow(config).to receive(:limit_exceeded?).and_return(true)
        end

        shared_examples 'throttles the request' do
          it 'throttles the request' do
            expect(cache).to receive(:write).with(discriminator, 21, 11)
            expect(cache).to receive(:count).with("1:#{discriminator}:requests", 11).and_return(3)
            expect(cache).to receive(:count_by).with("1:#{discriminator}:runtime", anything, anything).and_return(1)
            expect(cache).to receive(:count_by).with("1:#{discriminator}:db_runtime", anything, anything).and_return(1)
            subject.process_action(event)
          end
        end

        include_examples 'throttles the request'

        context 'with a custom ruleset' do
          let(:ruleset) { 'custom-rules' }
          let(:discriminator) { 'ip:127.0.0.1;ruleset:custom-rules' }
          include_examples 'throttles the request'
        end
      end
    end
  end
end

RSpec.describe Throttle::Cache do
  let(:cache) { Throttle::Cache.instance }

  describe '#read' do
    it 'reads a value from the cache' do
      key = 'read'
      value = 'example_value'
      expires_in = 1.hour

      cache.write(key, value, expires_in)

      expect(cache.read(key)).to eq(value)
    end
  end

  describe '#write' do
    it 'writes a value to the cache' do
      key = 'write'
      value = 'example_value'
      expires_in = 1.hour

      cache.write(key, value, expires_in)

      expect(cache.read(key)).to eq(value)
    end
  end

  describe '#count' do
    it 'increments the count by 1' do
      key = 'count'
      expires_in = 1.hour

      expect(cache.count(key, expires_in)).to eq(1)
      expect(cache.count(key, expires_in)).to eq(2)
    end
  end

  describe '#count_by' do
    it 'increments the count by the specified value' do
      key = 'count_by'
      expires_in = 1.hour
      value = 5

      expect(cache.count_by(key, expires_in, value)).to eq(value)
      expect(cache.count_by(key, expires_in, value)).to eq(value * 2)
    end
  end
end
