# frozen_string_literal: true

require 'rspec/expectations'

RSpec::Matchers.define :contain_data do |data|
  match do |stream|
    pos = stream.pos
    contents = stream.read
    stream.seek(pos, IO::SEEK_SET)
    contents == data
  end
end
