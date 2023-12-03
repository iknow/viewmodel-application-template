# frozen_string_literal: true

module Types; end
class Types::Serializer < ActiveRecord::Type::Value
  def initialize(serializer, chain: nil)
    super()

    @serializer = serializer
    @chain      = chain
  end

  def serialize(value)
    result = serializer.dump(value)
    result = chain.serialize(result) if chain
    result
  end

  def deserialize(value)
    value = chain.deserialize(value) if chain
    serializer.load(value)
  end

  private

  attr_reader :serializer

  # Because tables might not exist at model initialization time, allow the
  # chained Type to be provided as a lazily evaluated proc.
  def chain
    @chain = @chain.call if @chain.is_a?(Proc)
    @chain
  end
end
