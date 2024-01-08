# frozen_string_literal: true

source 'https://rubygems.org'
git_source(:github) { |repo| 'https://github.com/#{repo}.git' }

ruby '3.2.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 7.1.0'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem 'sprockets-rails'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.0'

# Bundle and transpile JavaScript [https://github.com/rails/jsbundling-rails]
gem 'jsbundling-rails'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem 'jbuilder'

# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 4.0'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem 'kredis'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem 'bcrypt', '~> 3.1.7'

gem 'tzinfo'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Sass to process CSS
# gem 'sassc-rails'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem 'image_processing', '~> 1.2'

# Handle CORS
gem 'rack-cors'

# Stop abusive clients
gem 'rack-attack'

# For cleaner production logs
gem 'lograge'

# Honeybadger for error reporting
gem 'honeybadger'

# Memcache and Redis
gem 'dalli'
gem 'redis', '~> 4.0'

# Elasticsearch
gem 'chewy'
gem 'elasticsearch', '~> 7.13.0'
gem 'faraday_middleware-aws-sigv4'

# Postgres-based ActiveJob backend
gem 'good_job'

# HTTP library used by elasticsearch-ruby
gem 'typhoeus'

# AWS SDK access
gem 'aws-sdk-s3'

# Faster JSON library
gem 'oj'

# Enumerated types
gem 'renum'

# re-encode binary strings using arbitrary symbolic bases
gem 'base_x'

# Parser combinator library
gem 'raabro'

# Use factory_bot for generating content in tests
gem 'factory_bot', require: false
gem 'factory_bot_rails', groups: [:development, :test]

# iKnow and Viewmodels gems
gem 'acts_as_manual_list', '~> 0.1.2'
gem 'deep_preloader',      '~> 1.1.0'
gem 'iknow_cache',         '~> 1.2.0'
gem 'iknow_params',        '~> 2.3.1'
gem 'iknow_view_models',   '~> 3.7.2'
gem 'keyword_builder',     '~> 1.0.0'
gem 'loadable_config',     '~> 1.0.3'
gem 'persistent_enum',     '~> 1.2.6'
gem 'safe_values',         '~> 1.0.2'

group :development, :test do
  gem 'debug'
  gem 'fuubar'
  gem 'rspec-rails'
  gem 'rubocop'
  gem 'rubocop-iknow', '>= 0.0.12'
  gem 'rubocop-rails'
  gem 'webmock'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem 'web-console'

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem 'rack-mini-profiler'

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem 'spring'

  gem 'annotate'
  gem 'ruby-lsp', require: false
  gem 'solargraph', '>= 0.39'

  gem 'foreman'
end
