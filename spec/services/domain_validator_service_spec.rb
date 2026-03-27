# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DomainValidatorService do
  let(:mock_config) do
    MockLoadableConfig.new(
      DomainValidatorConfig,
      enabled: true)
  end

  subject do
    DomainValidatorService.new
  end

  before(:each) do
    allow(DomainValidatorService).to receive(:config).and_return(mock_config)
  end

  def service_url_for(domain)
    uri = mock_config.api_base
    uri.path = DomainValidatorService.api_path(domain)
    uri.to_s
  end

  let!(:legit_domain_stub) do
    stub_request(:get, service_url_for('google.com'))
      .to_return(status: 200, body: '{"status":200,"disposable":false}')
  end

  let!(:legit_unicode_domain_stub) do
    stub_request(:get, service_url_for(IDN::Idna.toASCII('åéîøü.com')))
      .to_return(status: 200, body: '{"status":200,"disposable":false}')
  end

  let!(:disposable_domain_stub) do
    stub_request(:get, service_url_for('tempmail.org'))
      .to_return(status: 200, body: '{"status":200,"disposable":true}')
  end

  let!(:request_limit_reached_stub) do
    stub_request(:get, service_url_for('ratelimit.com'))
      .to_return(status: 429, body: '{"status":429,"error":"Rate limit exceeded."}')
  end

  let!(:invalid_domain_stub) do
    stub_request(:get, service_url_for('invaliddomain.ry'))
      .to_return(status: 400, body: '{"status":400,"error":"The domain is invalid."}')
  end

  let!(:invalid_response_stub) do
    stub_request(:get, service_url_for('invalid.response'))
      .to_return(status: 500, body: '<html><head></head><body><body/>')
  end

  let(:dns_result_message) do
    message = Dnsruby::Message.new
    rr = Dnsruby::RR::IN::MX.new
    rr.from_hash(preference: 10, exchange: 'smtp.google.com')
    message.add_answer!(rr)
    message
  end

  let(:dns_result_error) { nil }

  let(:dns_result) do
    ['queryname', dns_result_message, dns_result_error]
  end

  before(:each) do
    mock_resolver = instance_double(Dnsruby::Resolver)
    allow(Dnsruby::Resolver).to receive(:new).and_return(mock_resolver)
    allow(mock_resolver).to receive(:do_validation=)
    allow(mock_resolver).to receive(:query_timeout=)
    allow(mock_resolver).to receive(:close)
    allow(mock_resolver).to receive(:send_async) do |_message, queue|
      queue.push(dns_result)
    end
  end

  before(:each) do
    # Ensure cached results don't mutually interfere
    Rails.cache.clear
  end

  describe 'domain?' do
    it 'returns true with a valid domain' do
      expect(subject.domain?('gmail.com')).to eq(true)
    end

    it 'returns true with a valid IDN' do
      expect(subject.domain?('ドメイン.jp')).to eq(true)
    end

    it 'returns false with an invalid IDN' do
      expect(subject.domain?('xn--ドメイン.jp')).to eq(false)
    end

    it 'returns false with an invalid domain' do
      expect(subject.domain?('gmail,com')).to eq(false)
    end
  end

  describe 'permitted_domain?' do
    it 'returns true with a valid domain' do
      expect(subject).to receive(:cache_valid_domain!).and_return(nil)
      expect(subject.permitted_domain?('google.com')).to eq(true)
      expect(legit_domain_stub).to have_been_requested
    end

    it 'returns true with a valid unicode domain' do
      expect(subject).to receive(:cache_valid_domain!).and_return(nil)
      expect(subject.permitted_domain?('åéîøü.com')).to eq(true)
      expect(legit_unicode_domain_stub).to have_been_requested
    end

    it 'returns true early with a cached valid domain' do
      expect(subject).to receive(:cached_as_valid?).and_return(true)
      expect(subject.permitted_domain?('google.com')).to eq(true)
      expect(legit_domain_stub).not_to have_been_requested
    end

    context 'dns validation' do
      context 'with a domain that returns no answers' do
        let(:dns_result_message) do
          Dnsruby::Message.new
        end

        it 'returns false early' do
          expect(subject.permitted_domain?('google.com')).to eq(false)
          expect(legit_domain_stub).not_to have_been_requested
        end
      end

      context 'with a domain that returns nxdomain' do
        let(:dns_result_message) do
          message = Dnsruby::Message.new
          message.header.rcode = Dnsruby::RCode::NXDOMAIN
          message
        end

        let(:dns_result_error) do
          Dnsruby::NXDomain.new('')
        end

        it 'returns false early' do
          expect(subject.permitted_domain?('google.com')).to eq(false)
          expect(legit_domain_stub).not_to have_been_requested
        end
      end

      context 'with a domain that returns servfail' do
        let(:dns_result_message) do
          message = Dnsruby::Message.new
          message.header.rcode = Dnsruby::RCode::SERVFAIL
          message
        end

        let(:dns_result_error) do
          Dnsruby::ServFail.new('')
        end

        it 'allows it through to usercheck' do
          expect(subject.permitted_domain?('google.com')).to eq(true)
          expect(legit_domain_stub).to have_been_requested
        end
      end

      context 'with a dns timeout' do
        let(:dns_result_message) do
          nil
        end

        let(:dns_result_error) do
          Dnsruby::ResolvTimeout.new('')
        end

        it 'allows it through to usercheck' do
          expect(subject.permitted_domain?('google.com')).to eq(true)
          expect(legit_domain_stub).to have_been_requested
        end
      end
    end

    it 'returns false early with a recorded disposable domain' do
      BlockedEmailDomain.create!(name: 'tempmail.org')
      expect(subject.permitted_domain?('tempmail.org')).to eq(false)
      expect(disposable_domain_stub).not_to have_been_requested
    end

    # The blocked domain recording is implemented as a transaction hook, which
    # interferes with transactional tests
    def stub_blocked_domain_recording!(domain)
      recorder_double = instance_double(DomainValidatorService::BlockedDomainRecorder)
      expect(recorder_double).to receive(:add_to_transaction)
      expect(DomainValidatorService::BlockedDomainRecorder).to receive(:new).with(domain).and_return(recorder_double)
    end

    it 'returns false with a disposable domain' do
      stub_blocked_domain_recording!('tempmail.org')
      expect(subject.permitted_domain?('tempmail.org')).to eq(false)
      expect(disposable_domain_stub).to have_been_requested
    end

    it 'returns true when rate limited' do
      expect(Honeybadger).to receive(:notify).with(kind_of(ApiClient::ApiError), context: kind_of(Hash))
      expect(subject.permitted_domain?('ratelimit.com')).to eq(true)
      expect(request_limit_reached_stub).to have_been_requested
    end

    it 'return false with invalid domain' do
      stub_blocked_domain_recording!('invaliddomain.ry')
      expect(Honeybadger).not_to receive(:notify)
      expect(subject.permitted_domain?('invaliddomain.ry')).to eq(false)
      expect(invalid_domain_stub).to have_been_requested
    end

    it 'return true and does not cache with invalid response' do
      expect(Honeybadger).to receive(:notify).with(kind_of(ApiClient::ApiError), context: kind_of(Hash))
      expect(subject).not_to receive(:cache_valid_domain!)
      expect(subject.permitted_domain?('invalid.response')).to eq(true)
      expect(invalid_response_stub).to have_been_requested
    end
  end

  describe 'self.api_path' do
    it 'returns correct API path for domain' do
      expect(DomainValidatorService.api_path('example.com').to_s)
        .to eq('/domain/example.com')
    end
  end

  describe 'BlockedDomainRecorder#record_blocked_domain' do
    subject { DomainValidatorService::BlockedDomainRecorder.new(domain) }
    let(:domain) { 'tempmail.org' }

    it 'creates the block' do
      subject.send(:record_blocked_domain)
      expect(BlockedEmailDomain.find_by(name: domain)).to be_present
    end

    context 'indexing' do
      include_examples 'with search indexes', { blocked_email_domain: BlockedEmailDomainsIndex }

      it 'updates the index' do
        expect(BlockedEmailDomainsIndex).to receive(:import_later)
        subject.send(:record_blocked_domain)
      end

      context 'when already present' do
        let_factory(:blocked_email_domain) { { name: domain } }
        it 'does not update the index' do
          expect(BlockedEmailDomainsIndex).not_to receive(:import_later)
          subject.send(:record_blocked_domain)
        end
      end
    end
  end
end
