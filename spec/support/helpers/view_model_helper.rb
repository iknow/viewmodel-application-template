# frozen_string_literal: true

require 'view_model/access_control'

module ViewModelHelper
  extend ActiveSupport::Concern

  include ViewModelTestUtils

  def serialize_to_hash(viewmodel, **context_options)
    viewmodel_class = Array.wrap(viewmodel).first.class
    ctx = vm_serialize_context(viewmodel_class, **context_options)
    ViewModel.serialize_to_hash(viewmodel, serialize_context: ctx)
  end

  def serialize_to_hash_with_refs(viewmodel, **context_options)
    viewmodel_class = Array.wrap(viewmodel).first.class
    ctx = vm_serialize_context(viewmodel_class, **context_options)
    super(viewmodel, serialize_context: ctx)
  end

  def serialize_to_new_hash_with_refs(viewmodel, id: nil, **context_options)
    viewmodel_class = Array.wrap(viewmodel).first.class
    ctx = vm_serialize_context(viewmodel_class, **context_options)
    super(viewmodel, id:, serialize_context: ctx)
  end

  def serialize_to_new_hash(viewmodel, id: nil, **context_options)
    viewmodel_class = Array.wrap(viewmodel).first.class
    ctx = vm_serialize_context(viewmodel_class, **context_options)
    super(viewmodel, id:, serialize_context: ctx)
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

  def alter_by_migrated_view!(viewmodel_class, model, edit_version,
                              additional_versions: {},
                              serialize_context:   vm_serialize_context(viewmodel_class),
                              deserialize_context: vm_deserialize_context(viewmodel_class))
    alter_by_view!(viewmodel_class, model, serialize_context:, deserialize_context:) do |data, references|
      down_migrator = ViewModel::DownMigrator.new({ viewmodel_class => edit_version, **additional_versions })
      down_migrator.migrate!({ 'data' => data, 'references' => references })

      yield(data, references)

      up_migrator = ViewModel::UpMigrator.new({ viewmodel_class => edit_version, **additional_versions })
      up_migrator.migrate!({ 'data' => data, 'references' => references })
    end
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
          ViewModel::GarbageCollection.garbage_collect_references!({ data: view, references: refs })
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
          ViewModel::GarbageCollection.garbage_collect_references!({ data: old_view, references: old_refs })
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
