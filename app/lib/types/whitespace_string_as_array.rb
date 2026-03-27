# frozen_string_literal: true

# Opposite of usual: we can dump using the rich array type, but need to load
# by joining into a string.
class Types::WhitespaceStringAsArray
  def load(array)
    array.join(' ')
  end

  def dump(string, json: nil)
    return [] if string.nil?

    string.split(/\s+/).sort
  end
end
