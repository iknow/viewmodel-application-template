# frozen_string_literal: true

module InvokeMethod
  class Matcher
    include RSpec::Matchers::Composable
    attr_reader :expected, :actual

    def initialize(method, *args)
      @method = method
      @args = args
    end

    def returning(matcher)
      @expected = matcher
      self
    end

    def matches?(other)
      @original = other
      @actual = @original.send(@method, *@args)
      values_match?(@expected, @actual)
    end

    def description
      "invoke_method('#{@method}' returning #{description_of(expected)})"
    end

    def failure_message
      "expected that return value #{actual} would match #{description_of(expected)}"
    end
  end

  def invoke_method(method, *args)
    Matcher.new(method, *args)
  end
end

RSpec.configure do |config|
  config.include(InvokeMethod)
end
