# frozen_string_literal: true

module UrlMatchers
  def contain_the_path(matcher)
    be_passed_to('url path parser') { |url| extract_url_path(url) }
      .returning(matcher)
  end

  def contain_the_resource(matcher)
    be_passed_to('url resource parser') { |url| extract_url_resource(url) }
      .returning(matcher)
  end

  def contain_the_fragment(matcher)
    be_passed_to('url fragment parser') { |url| extract_url_fragment(url) }
      .returning(matcher)
  end

  def contain_the_query(matcher)
    be_passed_to('url query parser') { |url| extract_url_query(url) }
      .returning(matcher)
  end

  def redirect_to_url(matcher)
    have_attributes(status: 302, location: matcher)
  end

  def extract_url_query(uri_string)
    uri = URI.parse(uri_string)
    Rack::Utils.parse_query(uri.query)
  end

  def extract_url_fragment(uri_string)
    uri = URI.parse(uri_string)
    Rack::Utils.parse_query(uri.fragment)
  end

  def extract_url_resource(uri_string)
    uri = URI.parse(uri_string)
    uri.fragment = nil
    uri.query    = nil
    uri.to_s
  end

  def extract_url_path(uri_string)
    uri = URI.parse(uri_string)
    uri.path
  end

  def compose_url(base, **components)
    uri = URI.parse(base)
    components.each do |component, value|
      uri.public_send(:"#{component}=", value)
    end
    uri.to_s
  end
end

RSpec.configure do |config|
  config.include(UrlMatchers)
end
