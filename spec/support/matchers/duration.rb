# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :be_the_iso_duration do |expected|
  match do |actual|
    ActiveSupport::Duration.parse(actual) == expected
  end
end
