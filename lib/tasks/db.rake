# frozen_string_literal: true

task :require_db_helpers do
  path = Rails.root.join('db', 'migrate', 'helpers', '*.rb')
  Dir[path].each { |file| require file }
end

Rake::Task['db:migrate'].enhance(['require_db_helpers'])
