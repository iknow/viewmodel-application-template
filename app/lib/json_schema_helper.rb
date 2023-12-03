# frozen_string_literal: true

class JsonSchemaHelper
  def self.build(&block)
    self.new.instance_exec(&block).deep_stringify_keys!
  end

  def self.parse!(&block)
    JsonSchema.parse!(build(&block))
  end

  def object(properties = {}, required = properties.keys, additional_properties = false)
    {
      type:                 'object',
      additionalProperties: additional_properties,
      properties:           properties.deep_stringify_keys,
      required:             required.map(&:to_s),
    }
  end

  def partial(properties, required = properties.keys)
    object(properties, required, true)
  end

  def array(member_schema, **rest)
    {
      type: 'array',
      items: member_schema.deep_stringify_keys,
      **rest,
    }
  end

  def string(**rest)
    {
      type: 'string',
      **rest,
    }
  end

  def boolean(**rest)
    {
      type: 'boolean',
      **rest,
    }
  end

  def integer(**rest)
    {
      type: 'integer',
      **rest,
    }
  end

  def number(**rest)
    {
      type: 'number',
      **rest,
    }
  end

  def any_of(*schemas)
    { anyOf: schemas }
  end

  def null
    { type: 'null' }
  end

  def nullable(schema)
    any_of(null, schema)
  end

  def enum(members)
    string(enum: members.map(&:to_s))
  end
end
