# frozen_string_literal: true

# To make polymorphic references less inefficient to store, we use a postgresql
# enumerated type whose members are the names of our models. We update this on
# boot.

Rails.application.config.to_prepare do
  begin
    connection = ApplicationRecord.connection
    type_exists = connection.select_value(
      "SELECT true FROM pg_type WHERE typname = 'model_name'")
  rescue ActiveRecord::NoDatabaseError
    next
  end

  if type_exists
    lock_id = 0x1d937f29255fb179 # random 64-bit key
    begin
      connection.execute("SELECT pg_advisory_lock(#{lock_id})")

      current_members = connection.select_values(<<~SQL)
        SELECT unnest(enum_range(null::model_name, null::model_name));
      SQL

      current_models = ModelRegistry.registered_models
                         .map(&:name)
                         .sort

      required_members = current_models - current_members

      required_members.each do |model_name|
        connection.execute("ALTER TYPE model_name ADD VALUE #{connection.quote(model_name)};")
      end

    ensure
      connection.execute("SELECT pg_advisory_unlock(#{lock_id})")
    end
  end
end
