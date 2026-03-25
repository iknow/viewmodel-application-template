# frozen_string_literal: true

module ActiveRecordDatabaseExists
  extend ActiveSupport::Concern

  class_methods do
    def database_and_table_exists?
      table_exists?
    rescue ActiveRecord::NoDatabaseError
      false
    end
  end
end

ActiveSupport.on_load(:active_record) { include ActiveRecordDatabaseExists }
