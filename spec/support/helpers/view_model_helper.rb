# frozen_string_literal: true

require 'view_model/test_helpers'
require 'view_model/access_control'

module ViewModelHelper
  extend ActiveSupport::Concern

  include ViewModel::TestHelpers

  def serialize_to_hash(viewmodel, **context_options)
    viewmodel_class = Array.wrap(viewmodel).first.class
    ctx = vm_serialize_context(viewmodel_class, **context_options)
    ViewModel.serialize_to_hash(viewmodel, serialize_context: ctx)
  end

  def serialize_to_hash_with_refs(viewmodel, **context_options)
    viewmodel_class = Array.wrap(viewmodel).first.class
    ctx = vm_serialize_context(viewmodel_class, **context_options)
    view = ViewModel.serialize_to_hash(viewmodel, serialize_context: ctx)
    refs = ctx.serialize_references_to_hash
    [view, refs]
  end

  def serialize_to_new_hash_with_refs(viewmodel, id: nil, **context_options)
    view_hash, refs = serialize_to_hash_with_refs(viewmodel, **context_options)
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

  def gc_refs(view, refs)
    ViewModel::GarbageCollection.garbage_collect_references!('data' => view, 'references' => refs)
  end

  def serialize_to_new_hash(viewmodel, id: nil, **context_options)
    view_hash, = serialize_to_new_hash_with_refs(viewmodel, id:, **context_options)
    view_hash
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

  def vm_request_ip
    '1.1.1.1'
  end

  def vm_request_context
    RequestContext.default
  end

  def vm_request_context_for(user, token_abilities: nil)
    permissions = user.effective_permissions
    token_abilities ||= permissions.referenced_abilities

    token = create(:doorkeeper_access_token, resource_owner: user, abilities: token_abilities)

    RequestContext.with(resource_owner: user,
                        permissions:,
                        ip: vm_request_ip,
                        doorkeeper_token: token)
  end

  def vm_access_control
    ViewModel::AccessControl::Open.new
  end

  def vm_serialize_context(vm_class = described_class, **kargs)
    default_args = {
      request_context: vm_request_context,
      access_control: vm_access_control,
    }
    vm_class.new_serialize_context(**default_args.merge(kargs))
  end

  def vm_deserialize_context(vm_class = described_class, **kargs)
    default_args = {
      request_context: vm_request_context,
      access_control: vm_access_control,
    }
    vm_class.new_deserialize_context(**default_args.merge(kargs))
  end

  # Overrides the one in ViewModel::TestHelpers to use different default argument values
  def alter_by_view!(viewmodel_class, model,
                     serialize_context:   vm_serialize_context(viewmodel_class),
                     deserialize_context: vm_deserialize_context(viewmodel_class))
    super(viewmodel_class, model, serialize_context:, deserialize_context:)
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

  def merge_viewmodel_metadata(hash, view_model_class, mark_as_new: false)
    default_metadata = {
      ViewModel::TYPE_ATTRIBUTE    => view_model_class.view_name,
      ViewModel::VERSION_ATTRIBUTE => view_model_class.schema_version,
      ViewModel::NEW_ATTRIBUTE     => mark_as_new,
    }
    default_metadata.merge(hash)
  end

  RSpec.shared_examples 'can run all defined migrations' do |viewmodel_class|
    model_class = viewmodel_class.model_class

    let(:latest_version_view) do
      model = create(model_class.name.underscore)
      viewmodel = viewmodel_class.new(model)
      serialize_to_hash_with_refs(viewmodel)
    end

    (1 ... viewmodel_class.schema_version).each do |version|
      begin
        path = viewmodel_class.migration_path(from: version, to: viewmodel_class.schema_version)
      rescue ViewModel::Migration::NoPathError
        next
      end

      it "migrates down to #{version}" do
        view, refs = latest_version_view

        expect {
          path.reverse_each { |m| m.down(view, refs) }
        }.not_to raise_error

        @@down_result_cache ||= {}
        @@down_result_cache[version] = [view, refs]
      end

      it "migrates up from #{version} if defined" do
        skip 'down migration failed' unless defined?(@@down_result_cache)

        old_view, old_refs = @@down_result_cache[version]
        skip 'down migration failed' unless old_view

        expect do
          path.each { |m| m.up(old_view, old_refs) }
        rescue ViewModel::Migration::OneWayError
          nil
        end.not_to raise_error
      end
    end
  end

  class ViewTestBase < ViewModel::ActiveRecord
    self.abstract_class = true
    extend AssociationCustomizer::Customizable
  end

  class_methods do
    def with_viewmodel(name, context: :context, viewmodel_base: ViewTestBase, &block)
      viewmodel_builder = nil

      before(context) do
        _self     = self
        with_self = ->(builder) { builder.instance_exec(_self, &block) }

        viewmodel_builder = ViewModel::TestHelpers::ARVMBuilder.new(name, viewmodel_base:, &with_self)
      end

      after(context) do
        viewmodel_builder.teardown
      end
    end
  end
end
