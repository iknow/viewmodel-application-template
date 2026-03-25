# frozen_string_literal: true

class DomainValidatorService
  DOMAIN_REGEX = /\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\Z/i

  RESPONSE_SCHEMA = JsonSchemaHelper.parse! do
    object(
      { status: integer, disposable: boolean },
      ['status', 'disposable'],
      true)
  end

  CACHE_PREFIX = 'acceptable_domains/'
  CACHE_TIME = 1.week

  # Top 50 domains observed on existing user accounts
  NEVER_BLOCK_LIST = Set.new(%w[
    gmail.com eikaiwa.dmm.com yahoo.co.jp hotmail.com icloud.com yahoo.com naver.com ezweb.ne.jp yahoo.com.tw i.softbank.jp outlook.com
    docomo.ne.jp hotmail.co.jp outlook.jp hanmail.net softbank.ne.jp dmme.sakura.ne.jp mail.ru me.com nifty.com kcgrp.jp nate.com
    qq.com dmm.email dmm-e.com yandex.com yahoo.ne.jp msn.com live.jp ybb.ne.jp bibo.com.ph au.com live.com hotmail.co.th yandex.ru
    protonmail.com daum.net g.softbank.co.jp ymail.com deped.gov.ph aol.com yahoo.com.br yahoo.com.ph windowslive.com hotmail.co.uk
    jcom.home.ne.jp otmail.jp mac.com ymobile.ne.jp
  ]).freeze

  BlockedDomainRecorder = Struct.new(:domain) do
    include ViewModel::AfterTransactionRunner

    def after_commit
      record_blocked_domain
    end

    def after_rollback
      record_blocked_domain
    end

    private

    def record_blocked_domain
      result = BlockedEmailDomain.insert({ name: domain, automatic: true }, unique_by: [:name], returning: :id)

      if ((id,) = result.rows.first)
        BlockedEmailDomainsIndex.import_later(id)
      end
    rescue ActiveRecord::ActiveRecordError => e
      Honeybadger.notify(e, context: {
        message: "Failed to record blocked domain '#{domain}'",
        error:   e.message,
      })
    end
  end

  class << self
    def config
      DomainValidatorConfig.instance
    end

    def api_path(domain)
      "/domain/#{domain}"
    end
  end

  def domain?(domain)
    to_ascii_domain(domain) != nil
  end

  def permitted_domain?(domain)
    # If the domain is unicode, canonicalize on the IDN representation
    domain = to_ascii_domain(domain)

    return false if domain.nil? # invalid domains should not be permitted
    return false if BlockedEmailDomain.where(name: domain).exists?
    return true if NEVER_BLOCK_LIST.include?(domain)
    return true if cached_as_valid?(domain)
    return true unless self.class.config.enabled

    # We can more cheaply check a domain's existence in DNS directly than by
    # using the UserCheck API. If the domain doesn't exist, we want to reject
    # it, but not persist the result as a block since it's not a positive match
    # for a disposable service.
    return false unless valid_dns?(domain)

    valid, detail =
      begin
        response_body = lookup_domain(domain)
        [!response_body['disposable'], response_body.to_json]
      rescue ApiClient::ApiError => e
        if invalid_domain_error?(e)
          # An domain reported as invalid that nonetheless passed the DNS check
          # is considered a sufficiently positive match to be recorded
          [false, 'invalid domain']
        else
          # Errors are considered transient: they should be reported, and the
          # domain is permitted once without caching.
          notify_api_error(domain, e)
          return true
        end
      end

    if valid
      cache_valid_domain!(domain)
    else
      Rails.logger.warn("DomainValidatorService adding block for disposable email domain '#{domain}' (reason: #{detail})")
      record_invalid_domain!(domain)
    end

    valid
  end

  def lookup_domain(domain)
    config = self.class.config
    uri = config.api_base
    uri.path = self.class.api_path(domain)

    headers = {}
    headers['Authorization'] = "Bearer #{config.api_key}" if config.api_key

    response = ApiClient.new.make_request(
      uri,
      method: :get,
      headers:,
      response_type: ApiClient::BodyType::Json,
      response_schema: RESPONSE_SCHEMA)

    response.result
  end

  def valid_dns?(domain, types = ['MX', 'A', 'AAAA'])
    config_info =
      Dnsruby::Config.default_config_hash
        .merge(apply_search_list: false, apply_domain: false)

    config = Dnsruby::Config.new.tap { |c| c.set_config_info(config_info) }

    resolver = Dnsruby::Resolver.new(config)
    resolver.do_validation = false
    resolver.query_timeout = 1
    queue = Queue.new

    types.each do |type|
      message = Dnsruby::Message.new(domain, type)
      message.header.rd = 1 # request recursion
      message.header.cd = false # request no dnssec validation
      message.do_validation = false
      resolver.send_async(message, queue)
    end

    types.any? do |_|
      # consider the next response, doesn't matter which
      _id, reply, exception = queue.pop

      case exception
      when Dnsruby::ResolvTimeout
        # On first timeout error, give up entirely and fall back to Usercheck
        Rails.logger.debug { "DNS timeout resolving #{domain}" }
        return true
      when Dnsruby::NXDomain
        false
      when Dnsruby::ResolvError
        # Resolution error such as SRVFAIL: we have to assume that it could have
        # existed if it weren't for the error
        Rails.logger.debug { "DNS resolution error resolving #{domain}: #{exception}" }
        true
      else
        # consider the reply
        if reply.rcode.code == Dnsruby::RCode::NOERROR
          reply.answer.present?
        else
          Rails.logger.debug { "DNS resolution error resolving #{domain}: reply rcode '#{reply.rcode.string}'" }
          true # unknown error
        end
      end
    end
  ensure
    resolver&.close
  end

  private

  def cached_as_valid?(domain)
    !!Rails.cache.read(CACHE_PREFIX + domain)
  end

  def cache_valid_domain!(domain)
    Rails.cache.write(CACHE_PREFIX + domain, true, expires_in: CACHE_TIME)
  end

  def record_invalid_domain!(domain)
    BlockedDomainRecorder.new(domain).add_to_transaction
  end

  INVALID_DOMAIN_RESPONSE = {
    'error'  => 'The domain is invalid.',
    'status' => 400,
  }.freeze

  def invalid_domain_error?(err)
    return false unless err.response && err.response.code == 400

    # An invalid domain string is considered a legitimate negative response,
    # users will enter these regularly.
    response_body = JSON.parse(err.response_body) rescue nil
    response_body == INVALID_DOMAIN_RESPONSE
  end

  def notify_api_error(domain, err)
    context = err.to_honeybadger_context
                .merge(message: "Failed to externally validate domain #{domain}")
    Honeybadger.notify(err, context:)
  end

  def to_ascii_domain(domain)
    ascii_domain = IDN::Idna.toASCII(domain)
    return nil unless DOMAIN_REGEX.match?(ascii_domain)

    ascii_domain
  rescue IDN::Idna::IdnaError
    nil
  end
end
