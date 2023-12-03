# frozen_string_literal: true

require 'oj'

Oj::Rails.set_encoder
Oj::Rails.set_decoder
Oj::Rails.optimize
Oj::Rails.mimic_JSON
