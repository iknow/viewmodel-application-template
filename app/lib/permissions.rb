# frozen_string_literal: true

class Permissions
  class UnauthenticatedError < ViewModel::AbstractError
    attr_reader :detail

    status 401
    code   'Auth.NotLoggedIn'
    detail 'Forbidden: must be logged in.'
  end

  class MissingUserError < ViewModel::AbstractError
    status 403
    code 'Auth.NotAUser'
    detail 'Forbidden: must be logged in as a user'
  end

  class MissingAbilityError < ViewModel::AbstractError
    attr_reader :required_abilities

    status 403
    code 'Auth.MissingAbility'

    def initialize(required_abilities)
      @required_abilities = Array.wrap(required_abilities)
      super()
    end

    def detail
      "Forbidden: one of the following abilities required: [#{required_ability_names.join(', ')}]"
    end

    def meta
      {
        abilities: required_ability_names,
      }
    end

    private

    def required_ability_names
      required_abilities.map(&:name)
    end
  end

  def self.authenticated(abilities: [])
    self.new(true, abilities)
  end

  def self.unauthenticated
    self.new(false, [])
  end

  def self.all
    self.authenticated(abilities: Ability.values.to_a)
  end

  attr_reader :abilities

  def initialize(authenticated, abilities)
    @authenticated = authenticated
    @abilities     = abilities.to_set.freeze

    unless @authenticated || @abilities.empty?
      raise RuntimeError.new('Illegal permissions: unauthenticated with abilities')
    end

    self.freeze
  end

  def authenticated?
    @authenticated
  end

  def includes_ability?(ability)
    return false unless authenticated?

    abilities.include?(ability)
  end

  def includes_any_ability?(abilities)
    return false unless authenticated?

    abilities.any? { |a| includes_ability?(a) }
  end

  def authorize!
    unless authenticated?
      raise UnauthenticatedError.new
    end
  end

  # Verify that the user has at least one of the specified abilities
  def authorize_ability!(*abilities)
    authorize!
    unless includes_any_ability?(abilities)
      raise MissingAbilityError.new(abilities)
    end
  end

  def merge(other)
    self.class.new(
      authenticated? || other.authenticated?,
      abilities + other.abilities)
  end

  def limit(permitted_abilities)
    self.class.new(
      authenticated?,
      abilities & permitted_abilities)
  end

  def ==(other)
    self.authenticated? == other.authenticated? &&
      self.abilities == other.abilities
  end

  def to_s
    if authenticated?
      names = abilities.map(&:name).join(', ')

      "<Permissions:authenticated(#{names})>"
    else
      '<Permissions:unauthenticated>'
    end
  end

  alias inspect to_s
end
