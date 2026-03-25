# frozen_string_literal: true

class DatabaseTimeout
  def self.with_timeout(timeout, conn = ActiveRecord::Base.connection, &block)
    original_timeout = conn.select_value('SHOW statement_timeout')
    conn.execute("SET SESSION statement_timeout = #{conn.quote(timeout)}")
    block.call(conn)
  ensure
    begin
      conn.execute("SET SESSION statement_timeout = #{conn.quote(original_timeout)}")
    rescue ActiveRecord::StatementInvalid => e
      raise unless e.cause.is_a?(PG::InFailedSqlTransaction)
    end
  end
end
