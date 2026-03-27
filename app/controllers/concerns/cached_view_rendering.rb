# frozen_string_literal: true

##
# Adds rendering for JSON viewmodel serializations from ViewModelCache.
module CachedViewRendering
  extend ActiveSupport::Concern

  def prerender_viewmodels_from_cache(views, serialize_context:, locked: false)
    if views.blank?
      return prerender_viewmodel(views, serialize_context:)
    end

    # Depending on whether a migration needs to affect references, it might
    # block caching the migrated versions. In the case that it does, we just
    # need to render the latest version and migrate afterwards.
    initial_migrations, post_migrations =
      if prerendered_migrations_blocked?
        [nil, migration_versions]
      else
        [migration_versions, nil]
      end

    viewmodel_class = Array.wrap(views).first.class
    json_views, json_refs = viewmodel_class.serialize_from_cache(views, migration_versions: initial_migrations, serialize_context:, locked:)

    # If the migration could not be run in isolation, it needs to be run on the
    # complete result. This is definitely a slow path, because this process
    # won't be cached.
    if post_migrations.present?
      parsed_views = ViewModel::Utils.map_one_or_many(json_views) { |view| Oj.load(view, mode: :strict) }
      parsed_references = json_refs.transform_values { |json| Oj.load(json, mode: :strict) }

      migrator = ViewModel::DownMigrator.new(migration_versions)
      migrator.migrate!({ 'data' => parsed_views, 'references' => parsed_references })

      json_views = ViewModel::Utils.map_one_or_many(parsed_views) { |view| Oj.dump(view, mode: :strict) }
      json_refs = parsed_references.transform_values { |hash| Oj.dump(hash, mode: :strict) }
    end

    prerender_json_view(json_views, json_references: json_refs) do |json|
      meta = json.attributes!['meta']
      if migration_versions.present? && meta.present?
        # Down-migrate the metadata in isolation. This means that migrations on
        # metadata types that manipulate references can't be used in the
        # presence of cached view rendering. This is a limitation, but not one
        # that is likely to be regularly encountered.
        migrator = ViewModel::DownMigrator.new(migration_versions)
        migrator.migrate!({ 'meta' => meta })
      end
    end
  end

  def render_viewmodels_from_cache(views, status: nil, serialize_context:)
    prerender = prerender_viewmodels_from_cache(views, serialize_context:)
    render_json_string(prerender, status:)
  end

  def prerendered_migrations_blocked?
    false
  end
end
