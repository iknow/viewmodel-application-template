# frozen_string_literal: true

require "rails/code_statistics"

[
  ['AccessControl', 'app/access_control'],
  ['Chewy',         'app/chewy'],
  ['Config',        'app/config'],
  ['Csvs',          'app/csvs'],
  ['Lib',           'app/lib'],
  ['Searches',      'app/searches'],
  ['Services',      'app/services'],
  ['Viewmodels',    'app/viewmodels'],
].each { |n, p| Rails::CodeStatistics.register_directory(n, p) }
