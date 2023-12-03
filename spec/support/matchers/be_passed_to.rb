# frozen_string_literal: true

module BePassedTo
  class Matcher
    include RSpec::Matchers::Composable
    attr_reader :expected, :actual

    def initialize(name = 'block', &block)
      @name  = name
      @block = block
    end

    def returning(matcher)
      @expected = matcher
      self
    end

    def matches?(original)
      @original = original
      @actual =
        begin
          @block.call(@original)
        rescue => ex
          @block_error = ex
          return false
        end
      values_match?(@expected, @actual)
    end

    def description
      "be_passed_to(a #{@name} returning #{description_of(expected)})"
    end

    def failure_message
      if @block_error
        "expected the #{@name} to return a value but it raised #{@block_error.inspect}"
      else
        "expected the #{@name} result #{actual} would match #{description_of(expected)}"
      end
    end

    def diffable?
      true
    end
  end

  def be_passed_to(*args, &block)
    Matcher.new(*args, &block)
  end
end

RSpec.configure do |config|
  config.include(BePassedTo)
end
