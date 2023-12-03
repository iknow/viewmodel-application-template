# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :be_the_same_time_as do |expected|
  match do |actual|
    actual.change(nsec: 0) == expected.change(nsec: 0)
  end
end
