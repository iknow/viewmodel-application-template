# frozen_string_literal: true

module SharedExamplesLocalExtensionsHelper
  extend ActiveSupport::Concern

  # Methods for extending shared examples with specific context.
  # With `local_expectations` in context, supporting shared_examples can call
  # `additional_expectations` to access these extensions.
  class_methods do
    def local_expectations(&b)
      # We demand that any defined local expectations block gets run at least
      # once: this is to guard against misconfiguring rspec in a way that leaves
      # them silently not being invoked.
      #
      # In order that both shared_examples and their it_behaves_like blocks can
      # add local expectations despite them being evaluated in the same class,
      # we need to add the expectations by prepending a module with the new
      # expectations.
      mod = Module.new do
        class << self
          @expectations_evaluated = false
          def expectations_evaluated!
            @expectations_evaluated = true
          end

          def expectations_evaluated?
            @expectations_evaluated
          end
        end
      end

      mod.define_method(:additional_expectations) do
        super()
        mod.expectations_evaluated!
        instance_exec(&b)
      end

      self.prepend(mod)

      after(:context) do
        unless mod.expectations_evaluated?
          # RSpec doesn't print what context an after context hook fails in, so
          # in order to make it possible to track this down, we need to include
          # the path to the example in the error: we can get that from the class
          # it's evaluated in.
          expect(self.class.inspect).to eq('a context that calls local expectations')
        end
      end
    end

    def default_rejection_status
      403
    end

    def default_rejection_code
      'Auth.MissingAbility'
    end
  end

  def additional_expectations; end
end
