# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort('The Rails environment is running in production mode!') if Rails.env.production?
require 'spec_helper'
require 'rspec/rails'
require 'chewy/rspec'
Dir[Rails.root.join('spec', 'support', 'mocks', '**', '*.rb')].each { |file| require file }
Dir[Rails.root.join('spec', 'support', 'helpers', '*.rb')].each { |file| require file }
Dir[Rails.root.join('spec', 'support', 'matchers', '*.rb')].each { |file| require file }
# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# Dir[Rails.root.join('spec/support/**/*.rb')].each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
# If you are not using ActiveRecord, you can remove these lines.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

# Configure webmock, but allow ElasticSearch
require 'web_mock/http_lib_adapters/net_http2_adapter'
WebMock.disable_net_connect!(
  allow: [
    ElasticsearchConfig.host,
  ],
)

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [::Rails.root.join('spec', 'fixtures')]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     RSpec.describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://rspec.info/features/6-0/rspec-rails
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!
  # arbitrary gems may also be filtered via:
  # config.filter_gems_from_backtrace("gem name")

  config.include AwsHelper, :aws
  config.include JsonResponseHelper
  config.include ViewModelRequestHelper, type: :request
  config.include PaginatedRequestHelper, type: :request
  config.include FilteredRequestHelper,  type: :request
  config.include RequestHelper,          type: :request
  config.include SearchHelper,           type: :search
  config.include ChewyIndexHelper
  config.include MockHelper
  config.include GlobalHelper
  config.include ViewModelHelper,      type: :viewmodel
  config.include AccessControlHelper,  type: :access_control
  config.include MediaUploadHelper
  config.include FactoryHelper
  config.include SharedExamplesLocalExtensionsHelper

  # RSpec in default configuration includes a compatibility layer for the tagged
  # logging adapter in all of the Rails-specific example groups. If you say
  # `type: controller`, or `type: routing`, you will automatically get the
  # ControllerExampleGroup mixin, or the RoutingExampleGroup mixin, and these
  # will include the TaggedLoggingAdapter (via RailsExampleGroup). If your
  # example group is not rails specific, you will not get this helper.
  # Everything in this application is rails specific, so we always include the
  # rails helpers.
  config.include ::RSpec::Rails::RailsExampleGroup

  config.before(:suite) do
    Chewy.strategy(:bypass)
    Chewy.massacre
  end

  RSpec::Matchers.define_negated_matcher :not_eq, :eq
end
