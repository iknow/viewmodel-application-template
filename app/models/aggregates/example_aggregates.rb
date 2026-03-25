# frozen_string_literal: true

# Example aggregate class, with only one member
class Aggregates::ExampleAggregates < Aggregates::ApplicationAggregate
  self.model_class = Ability
  def self.requires_range? = false

  model_scope User, key: 'users.id' do
    Ability.joins('JOIN users ON (true)')
  end

  member :total_abilities, -> { Ability.select('count(*) AS total_abilities') }
end
