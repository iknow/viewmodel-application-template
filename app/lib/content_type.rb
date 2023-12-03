# frozen_string_literal: true

# Structure and parser for MIME content types with parameters
ContentType = Value.new(:media_type, :subtype, :params)

class ContentType
  class InvalidContentType < ArgumentError; end

  module Parser
    include Raabro

    UNQUOTED_TOKEN = /[-!#$%&'*+.^_`|~A-Za-z0-9]+/

    # rubocop:disable Layout/EmptyLineBetweenDefs

    # Parse
    def quote(i); str(nil, i, '"'); end
    def slash(i); str(nil, i, '/'); end
    def equals(i); str(nil, i, '='); end
    def param_sep(i); rex(nil, i, '\s*;\s*'); end

    def token(i); rex(:token, i, UNQUOTED_TOKEN); end

    def quoted_token_body(i); rex(nil, i, /(?:[^"\\]|\\[[:ascii:]])+/); end
    def quoted_token(i); seq(:quoted_token, i, :quote, :quoted_token_body, :quote); end

    def type(i); seq(:type, i, :token, :slash, :token); end

    def param_value(i); alt(:param_value, i, :token, :quoted_token); end
    def param(i); seq(:param, i, :token, :equals, :param_value); end

    def sep_and_param(i); seq(nil, i, :param_sep, :param); end

    def content_type(i); seq(:content_type, i, :type, :sep_and_param, '*'); end

    # Rewrite
    def rewrite_token(t); t.string; end

    def rewrite_quoted_token(t)
      t.children[1].string.gsub(/\\(.)/, '\1')
    end

    def rewrite_type(t); [rewrite(t.children[0]).downcase, rewrite(t.children[2]).downcase]; end

    def rewrite_param_value(t); rewrite(t.children[0]); end
    def rewrite_param(t); [rewrite(t.children[0]).downcase, rewrite(t.children[2])]; end
    def rewrite_sep_and_param(t); rewrite(t.children[1]); end

    def rewrite_content_type(t)
      type, subtype = rewrite(t.children[0])
      params = t.children[1..].map { |tt| rewrite(tt) }.to_h
      ContentType.new(type, subtype, params)
    end

    # rubocop:enable Layout/EmptyLineBetweenDefs
  end

  def self.parse(string)
    result = Parser.parse(string, error: true)
    if result.is_a?(Array)
      raise InvalidContentType.new(result.last)
    end

    result
  end

  def type
    "#{media_type}/#{subtype}"
  end

  def inspect
    "#<ContentType #{self}>"
  end

  def to_s
    ps = params.map do |k, v|
      unless /\A#{Parser::UNQUOTED_TOKEN}\Z/.match?(v)
        qv = v.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
        v = %("#{qv}")
      end
      "#{k}=#{v}"
    end

    [type, *ps].join(';')
  end

  # Data URL representation of the content type
  def rfc2397
    ps = params.map { |k, v| "#{k}=#{CGI.escape(v)}" }
    [type, *ps].join(';')
  end

  # Support implicit coercion to String
  alias to_str to_s
end
