# frozen_string_literal: true

# PersistentEnum models ensure that their enum constants are mirrored in the
# database. As such, if they're autoloaded from within a database transaction
# the initialization could be subject to rollback.
#
# We eager load ViewModels in order that they can be resolved by name from
# ViewModel::Registry without explicitly using `require_dependency` or literally
# naming the constant first.

Rails.application.config.to_prepare do
  ['models', 'viewmodels'].each do |dir|
    dir_root = Rails.root.join('app', dir)

    Dir.glob(dir_root.join('**', '*.rb')).each do |filename|
      require_dependency Pathname.new(filename).relative_path_from(dir_root)
    end
  end
end
