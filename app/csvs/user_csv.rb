# frozen_string_literal: true

class UserCsv < ApplicationCsv
  column :email
  column :name
  column :interface_language, format: ParamSerializers::Language
  column :created_at, format: ParamSerializers::TimeInZone, deserializer: nil
  column :updated_at, format: ParamSerializers::TimeInZone, deserializer: nil

  # Example dynamic columns
  dynamic_columns :dynamic_example do
    define_columns do |_request_filters|
      ['example1', 'example2']
    end

    serializer do |column_name|
      "#{column_name} value"
    end
  end

  # Example aggregate columns
  column :total_abilities do
    aggregates [Aggregates::ExampleAggregates]
    format ParamSerializers::Integer
    deserializer(nil)
    serializer do
      agg = aggregates[Aggregates::ExampleAggregates][view.id]
      if agg
        agg.public_send(:total_abilities)
      else
        empty_value
      end
    end
  end
end
