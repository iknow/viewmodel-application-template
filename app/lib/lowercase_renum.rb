# frozen_string_literal: true

# Renum requires its constants to be named as Ruby constants (since it installs
# them there). Sometimes we might prefer them to be a different format. Override
# `name` and lookup.
module LowercaseRenum
  extend ActiveSupport::Concern

  def name
    super.underscore
  end

  class_methods do
    def with_insensitive_name(name)
      with_name(name.underscore)
    end
  end
end
