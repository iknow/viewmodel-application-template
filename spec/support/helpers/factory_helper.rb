# frozen_string_literal: true

module FactoryHelper
  extend ActiveSupport::Concern

  # Select a uuid whose final component is the line number of the call location.
  # To select a call location from further up the stack, pass the `depth` parameter.
  def self.caller_uuid(depth: 1)
    loc = caller_locations(depth + 1, 1).first
    caller_lineno = loc.lineno
    SecureRandom.uuid.gsub(/.{12}$/, ('%0.12d' % caller_lineno))
  end

  class_methods do
    def caller_uuid(depth: 1)
      FactoryHelper.caller_uuid(depth: depth + 1)
    end

    def let_factory(name, type = name, *traits, build_only: false, &options_block)
      name_opts   = :"#{name}_options"
      name_traits = :"#{name}_traits"

      mod = Module.new
      mod.define_method(name_traits) { traits }

      options_block ||= proc { {} }
      mod.define_method(name_opts, &options_block)

      prepend(mod)

      loc = caller_locations(1, 1).first
      caller_path = loc.path
      caller_lineno = loc.lineno

      if build_only
        mod.define_method("let_factory__#{name}") do
          build(type, *self.send(name_traits), **self.send(name_opts))
        end
      else
        mod.define_method("let_factory__#{name}") do
          opts = self.send(name_opts)

          # Add a default uuid constructed around the line number in the caller of
          # the let_factory call, to make it easier to identify records from their
          # id in test failures.
          unless opts.has_key?(:id) || opts.has_key?('id')
            default_caller_id = SecureRandom.uuid.gsub(/.{12}$/, ('%0.12d' % caller_lineno))
            opts[:id] = default_caller_id
          end

          create(type, *self.send(name_traits), **opts)
        end
      end

      # Make the location of the let_factory call show up in the stack trace by
      # evaluating it with the path and line number of the calling context.
      # rubocop:disable Style/EvalWithLocation, Security/Eval, Style/DocumentDynamicEvalDefinition
      let!(name) do
        eval("let_factory__#{name}", binding, caller_path, caller_lineno)
      end
      # rubocop:enable Style/EvalWithLocation, Security/Eval, Style/DocumentDynamicEvalDefinition
    end

    def let_factory_options(name, *traits, &)
      mod = Module.new

      if traits.present?
        mod.define_method(:"#{name}_traits") do
          super() + traits
        end
      end

      if block_given?
        mod.define_method(:"#{name}_options") do
          parent = super()
          parent.merge(instance_exec(parent, &))
        end
      end

      prepend(mod)
    end
  end

  def caller_uuid(depth: 1)
    FactoryHelper.caller_uuid(depth: depth + 1)
  end
end
