# frozen_string_literal: true

module FactoryHelper
  extend ActiveSupport::Concern

  class_methods do
    def let_factory(name, type = name, *traits, build_only: false, &options_block)
      name_opts   = :"#{name}_options"
      name_traits = :"#{name}_traits"

      mod = Module.new
      mod.define_method(name_traits) { traits }

      options_block ||= proc { {} }
      mod.define_method(name_opts, &options_block)

      prepend(mod)

      loc = caller_locations.first

      if build_only
        mod.define_method("let_factory__#{name}") do
          build(type, *self.send(name_traits), **self.send(name_opts))
        end
      else
        mod.define_method("let_factory__#{name}") do
          create(type, *self.send(name_traits), **self.send(name_opts))
        end
      end

      # Make the location of the let_factory call show up in the stack trace by
      # evaluating it with the path and line number of the calling context.
      # rubocop:disable Style/EvalWithLocation, Security/Eval, Style/DocumentDynamicEvalDefinition
      let!(name) do
        eval("let_factory__#{name}", binding, loc.path, loc.lineno)
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

    def let_factory_traits(name, *traits)
      let_factory_options(name, *traits)
    end
  end
end
