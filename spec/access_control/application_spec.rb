# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationAccessControl, type: :access_control do
  include_examples 'mentions all referenced root view dependencies'
end
