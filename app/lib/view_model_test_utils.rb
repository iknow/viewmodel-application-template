# frozen_string_literal: true

require 'view_model/test_helpers'

module ViewModelTestUtils
  extend ActiveSupport::Concern

  include ViewModel::TestHelpers

  def serialize_to_hash_with_refs(viewmodel, serialize_context:)
    view = ViewModel.serialize_to_hash(viewmodel, serialize_context:)
    refs = serialize_context.serialize_references_to_hash
    [view, refs]
  end

  def serialize_to_new_hash_with_refs(viewmodel, id: nil, serialize_context:)
    _serialize_to_new_hash_with_refs(viewmodel, id:, serialize_context:)
  end

  # Underscore prefix is for internal calls, which would otherwise break when overriding methods have different types.
  def _serialize_to_new_hash_with_refs(viewmodel, id: nil, serialize_context:)
    view_hash = ViewModel.serialize_to_hash(viewmodel, serialize_context:)
    refs = serialize_context.serialize_references_to_hash
    strip_serialization_metadata(view_hash)

    if id
      view_hash['id'] = id
      view_hash[ViewModel::NEW_ATTRIBUTE] = true
    end

    # Retain only references used from the roots, as type/id
    refs.each_value do |ref_view|
      ref_view.slice!('id', '_type')
    end
    gc_refs(view_hash, refs)

    [view_hash, refs]
  end

  def serialize_to_new_hash(viewmodel, id: nil, serialize_context:)
    view_hash, = _serialize_to_new_hash_with_refs(viewmodel, id:, serialize_context:)
    view_hash
  end

  def gc_refs(view, refs)
    ViewModel::GarbageCollection.garbage_collect_references!('data' => view, 'references' => refs)
  end

  def serialize_reference(viewmodel_ref)
    ref      = "ref:#{SecureRandom.hex(10)}"
    ref_key  = { '_ref' => ref }
    ref_body = { ref => { '_type' => viewmodel_ref.viewmodel_class.view_name, 'id' => viewmodel_ref.model_id } }
    [ref_key, ref_body]
  end

  def fupdate_append(*views)
    fupdate = {
      '_type' => '_update',
      'actions' => [
        { '_type' => 'append', 'values' => views },
      ],
    }
  end

  # Traverse a VM serialization and strip identifying metadata
  def strip_serialization_metadata(x)
    case x
    when Hash
      x.delete('id')
      x.delete('lock_version')
      x.delete('created_at')
      x.each_value { |v| strip_serialization_metadata(v) }
    when Array
      x.each { |v| strip_serialization_metadata(v) }
    end
  end

  def merge_viewmodel_metadata(hash, view_model_class, mark_as_new: nil)
    metadata = {
      ViewModel::TYPE_ATTRIBUTE    => view_model_class.view_name,
      ViewModel::VERSION_ATTRIBUTE => view_model_class.schema_version,
    }

    unless mark_as_new.nil?
      metadata[ViewModel::NEW_ATTRIBUTE] = mark_as_new
    end

    metadata.merge(hash)
  end
end
