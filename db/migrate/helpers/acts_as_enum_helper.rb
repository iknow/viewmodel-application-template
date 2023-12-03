# frozen_string_literal: true

module ActsAsEnumHelper
  def create_acts_as_enum(table, name_attr: :name, initial_members: [])
    type = table.to_s.singularize

    members_sql = initial_members.map { |m| connection.quote(m) }.join(', ')
    execute "CREATE TYPE #{type} AS ENUM (#{members_sql})"

    create_table table, id: type do |t|
      t.string name_attr, null: false
      yield(t) if block_given?
      t.index [name_attr], unique: true
    end

    execute <<-SQL
      ALTER TABLE #{table}
      ADD CONSTRAINT #{table}_enum_matches_constant
      CHECK (id::text = #{name_attr})
    SQL

    if initial_members.present?
      execute <<-SQL
        INSERT INTO #{table} (id, #{name_attr})
          SELECT val, val FROM (
            SELECT unnest(enum_range(null::#{type}, null::#{type})) AS val
          ) AS vals
      SQL
    end
  end
end
