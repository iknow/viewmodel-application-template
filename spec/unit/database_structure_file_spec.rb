# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'database structure file' do
  def dump_schema_to_file(path)
    saved_schema = ENV['SCHEMA']
    ENV['SCHEMA'] = path
    db_config = ActiveRecord::Base.configurations.find_db_config(Rails.env)
    ActiveRecord::Tasks::DatabaseTasks.dump_schema(db_config)
  ensure
    ENV['SCHEMA'] = saved_schema
  end

  let(:current_db_structure) do
    Tempfile.create('structure') do |f|
      dump_schema_to_file(f.path)
      f.rewind
      f.read
    end
  end

  let(:structure_file) do
    db_config = ActiveRecord::Base.configurations.find_db_config(Rails.env)
    ActiveRecord::Tasks::DatabaseTasks.schema_dump_path(db_config)
  end

  it 'matches the database structure' do
    saved_structure = File.read(structure_file)

    expect(current_db_structure).to eq(saved_structure)
  end
end
