# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GoodJob do
  it 'has all migrations applied' do
    expect(GoodJob).to be_migrated
  end
end
