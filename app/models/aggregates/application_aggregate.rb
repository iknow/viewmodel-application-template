# frozen_string_literal: true

class Aggregates::ApplicationAggregate
  include ActiveModel::Model

  class << self
    # The model class must define a scope `intersecting`
    attr_accessor :model_class

    # Given a scope on model_class, a time range, and a key to group on,
    # calculate the aggregates required for the aggregate view, and return them
    # indexed by the grouping key.
    #
    # @returns Hash<uuid, ApplicationAggregate>
    def calculate_aggregates(key, scope, range, aggregates: nil)
      query = scope
      query = query.merge(self.range_scope(range)) if requires_range?
      query = query.merge(self.aggregate_scope(aggregates:)).group(key).select("#{key} AS _entity_id")
      rows = model_class.connection.select_all(query.to_sql)

      # select_all doesn't parse Interval columns into Durations by default.
      interval_columns =
        rows.column_types
          .filter { |k, v| k.is_a?(String) & v.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Interval) }
          .keys

      rows.each.to_h do |row|
        values = row.slice(*self.fields)

        interval_columns.each do |ic|
          values[ic] = ParamSerializers::FixedDuration.load(values[ic]) if values[ic]
        end

        [row['_entity_id'], self.new(values)]
      end
    end

    def empty_values
      self.members.transform_values { 0 }
    end

    def empty
      self.new(empty_values)
    end

    # Calculates periodic daily averages within a range of dates in a provided
    # timezone, returning ([key, period_start] => aggregate). The period size
    # can be any integer number of days.
    def calculate_periodic_aggregates(key, scope, range:, period_days:, timezone:)
      unless requires_range?
        raise ArgumentError.new('Period aggregation can only be used with range based aggregates')
      end

      unless range.begin.is_a?(Date) && range.end.is_a?(Date)
        raise ArgumentError.new('range must be a closed range of Dates')
      end

      # the timestamp range are the start of the first day and end of the last day of
      # the date range in the specified timezone. Note that this is an inclusive range.
      time_range = (range.begin.in_time_zone(timezone).utc ..
                    range.end.in_time_zone(timezone).end_of_day.utc)

      timezone_sql = model_class.connection.quote(timezone.identifier)

      periodic_key_sql =
        case periodic_key
        when Arel::Nodes::SqlLiteral
          periodic_key
        else
          q_table_name = PG::Connection.quote_ident(model_class.table_name)
          q_key_name = PG::Connection.quote_ident(periodic_key.to_s)
          "#{q_table_name}.#{q_key_name}"
        end

      periodic_date_sql = "date_trunc('day', timezone(#{timezone_sql}, #{periodic_key_sql} AT TIME ZONE 'utc'))::date"

      period_start_sql =
        if period_days == 1
          periodic_date_sql
        else
          start_date_sql = model_class.connection.quote(range.begin)
          step_size_sql  = model_class.connection.quote(period_days)

          "#{periodic_date_sql} - ((#{periodic_date_sql} - #{start_date_sql}) % #{step_size_sql})"
        end

      query = scope
        .select(Arel.sql("#{key} AS _entity_id"))
        .select(Arel.sql("#{period_start_sql} AS _period_start"))
        .merge(self.aggregate_scope)
        .merge(self.range_scope(time_range))
        .group(key, :_period_start)
        .order(key, :_period_start)

      rows = model_class.connection.select_all(query.to_sql)

      # select_all doesn't parse Interval columns into Durations by default.
      interval_columns =
        rows.column_types
          .filter { |k, v| k.is_a?(String) & v.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Interval) }
          .keys

      rows.each.to_h do |row|
        values = row.slice(*self.fields)

        interval_columns.each do |ic|
          values[ic] = ParamSerializers::FixedDuration.load(values[ic]) if values[ic]
        end

        [[row.fetch('_entity_id'), row.fetch('_period_start')], self.new(values)]
      end
    end

    def scope_for(model_class)
      scope_f, key = scopes.fetch(model_class) do
        raise ArgumentError.new("No aggregate scope defined for #{model_class.name}")
      end

      scope = scope_f.call
      [scope, key]
    end

    def requires_range?
      true
    end

    def range_scope(range)
      self.model_class.intersecting(range)
    end

    def aggregate_scope(aggregates: nil)
      queries =
        if aggregates
          self.members.values_at(*aggregates.map(&:to_s))
        else
          self.members.values
        end

      queries.inject(self.model_class.all) { |scope, query| scope.merge(query.call) }
    end

    def aggregate_name
      self.name.delete_prefix('Aggregates::').underscore.pluralize
    end

    def viewmodel_class
      expected_name = ViewModel::Registry.default_view_name(self.name)
      ViewModel::Registry.for_view_name(expected_name)
    end

    private

    # When computing periodic aggregates, which timestamp column should be used
    # for determining a record's period
    def periodic_key
      :created_at
    end

    def members
      @members ||= {}
    end

    def scopes
      @scopes ||= {}
    end

    def model_scope(other_class, key: "#{other_class.table_name}.id", &scope)
      scope ||= -> { self.model_class.all }
      scopes[other_class] = [scope, key]
    end

    def member(name, query)
      attr_accessor name

      members[name.to_s] = query
    end

    def fields
      members.keys
    end
  end
end
