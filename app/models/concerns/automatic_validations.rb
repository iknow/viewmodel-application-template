# frozen_string_literal: true

module AutomaticValidations
  extend ActiveSupport::Concern

  class_methods do
    # Adds a rails validation for each non-null column discovered in the
    # database. MUST BE INCLUDED LAST.
    #
    # If a non-null validation is added for a foreign key that will later
    # be configured as a belongs_to association, things will fail in
    # mysterious ways. For example, a new object tree cannot be saved via
    # `root.save!`. As such, this must come after all associations are
    # configured.
    def validates_all_not_null_columns!
      # If we have a database table, dynamically add a validation for each
      # not-null column.
      return unless database_and_table_exists?

      # We can only directly validate columns that Rails can safely look at before
      # attempting to persist. This excludes columns where Rails generates the
      # value (locking, timestamps), and foreign keys (for which Rails may have a
      # valid but unpersisted model in the association cache).
      #
      # We can also indirectly validate foreign keys via their associations.

      excluded_columns = Set.new(['id', 'updated_at', 'created_at'])

      excluded_columns << locking_column if locking_enabled?

      belongs_to_associations = reflect_on_all_associations.select(&:belongs_to?)
      belongs_to_associations.each do |association|
        excluded_columns << association.foreign_key
        excluded_columns << association.foreign_type if association.polymorphic?
      end

      validatable_cols = columns.reject do |c|
        c.null || c.default_function ||
          excluded_columns.include?(c.name)
      end

      validatable_cols.each do |c|
        validates c.name, nullness: { is_null: false }
      end

      # Check belongs_to associations via AssociationPresenceValidator
      optional_col_names = columns
                             .select { |c| c.null || c.default_function }
                             .map { |c| c.name }

      validatable_belongs_to_associations = belongs_to_associations.reject do |a|
        optional_col_names.include?(a.foreign_key)
      end

      validatable_belongs_to_associations.each do |a|
        validates a.name, association_presence: true
      end
    end

    def validates_all_string_columns!(except: [], allow_empty: [])
      # If we have a database table, dynamically add a validation for each
      # String column.
      return unless database_and_table_exists?

      except = except.map(&:to_s)
      allow_empty = allow_empty.map(&:to_s)

      target_columns = columns.select do |c|
        next false unless (c.type == :string || c.type == :text) && !except.include?(c.name)

        # Models can define attribute serializers which change the actual
        # observed type. We're only interested here in validating actual strings
        # and arrays of strings.
        attribute_type = type_for_attribute(c.name)
        attribute_type.is_a?(ActiveModel::Type::String) ||
          (attribute_type.is_a?(ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Array) &&
           attribute_type.subtype.is_a?(ActiveModel::Type::String))
      end

      array_columns, string_columns = target_columns.partition(&:array)

      string_columns.each do |c|
        # No string may have leading or trailing whitespace
        validates c.name, stripped_string: true

        # Empty strings are also not permitted unless explicitly allowed
        validates c.name, non_empty: true unless allow_empty.include?(c.name)

        # Null bytes are never allowed because Postgres won't accept them
        validates c.name, allow_nil: true, format: { without: /\u0000/, message: 'must not include null bytes' }
      end

      array_columns.each do |c|
        validates c.name, array: { stripped_string: true }
        validates c.name, array: { non_empty: true } unless allow_empty.include?(c.name)
        validates c.name, array: { format: { without: /\u0000/, message: 'must not include null bytes' } }
      end
    end
  end
end
