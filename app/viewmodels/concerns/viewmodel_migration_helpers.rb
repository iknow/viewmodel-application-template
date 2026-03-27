# frozen_string_literal: true

module ViewmodelMigrationHelpers
  extend ActiveSupport::Concern

  class_methods do
    # Helper for common migration actions
    #
    # @param adding_fields list of fields added
    # @param removing_fields map of removed field to default value
    # @param renaming_fields
    #   map of name in the `from` version to the name in the `to` version
    # @param [Number] from from version
    # @param [Number] to to version
    def migrates_by(adding_fields: [], removing_fields: {}, renaming_fields: {}, from:, to:)
      adding_fields   = adding_fields.map(&:to_s)
      removing_fields = removing_fields.map { |(k, v)| [k.to_s, v.freeze] }
      renaming_fields = renaming_fields.map { |(k, v)| [k.to_s, v.to_s] }

      migrates from:, to: do
        down do |view, refs|
          # Hide newly created fields
          adding_fields.each { |f| view.delete(f) }

          # Add dummy values for removed fields
          removing_fields.each do |from_name, default_value|
            view[from_name] =
              if default_value.is_a?(Proc)
                default_value.call(view, refs)
              else
                default_value
              end
          end

          renaming_fields.each do |from_name, to_name|
            view[from_name] = view.delete(to_name)
          end
        end
        up do |view, _refs|
          # Silently drop updates to removed fields
          removing_fields.each do |from_name, _default_value|
            view.delete(from_name)
          end

          renaming_fields.each do |from_name, to_name|
            view[to_name] = view.delete(from_name) if view.has_key?(from_name)
          end
        end
      end
    end

    # Define a simple migration for added optional fields, with a down-migration
    # removing them and an empty up-migration.
    def migrates_adding_fields(*fields, from:, to:)
      migrates_by(adding_fields: fields, from:, to:)
    end

    def migrates_renaming_fields(fields, from:, to:)
      migrates_by(renaming_fields: fields, from:, to:)
    end

    def migrates_removing_fields(field_map, from:, to:)
      migrates_by(removing_fields: field_map, from:, to:)
    end
  end
end
