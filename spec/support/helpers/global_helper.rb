# frozen_string_literal: true

module GlobalHelper
  # MacOS Ruby offers microsecond time resolution, while Linux Ruby offers
  # nanosecond resolution. Postgres is always microsecond resolution. Varying
  # resolution becomes an issue when comparing values that we round-trip through
  # the database. To mitigate this, the utc_now helper returns the time
  # truncated to microseconds.
  def utc_now
    t = Time.now.utc
    nsec = (t.nsec / 1000) * 1000
    t.change(nsec:)
  end

  # When initializing fields that are meant to be set by humans (e.g. lesson
  # times), we require these to be second-aligned.
  def utc_now_secs
    Time.now.utc.change(nsec: 0)
  end

  def a_uuid
    a_string_matching(/[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/i)
  end

  def a_url(schemes = nil)
    a_string_matching(UriRegex.anchored(schemes))
  end

  def an_https_url
    a_url(%w[http https])
  end
end
