# frozen_string_literal: true

class TimezoneSerializer < ActiveJob::Serializers::ObjectSerializer
  def serialize?(arg)
    arg.is_a?(::TZInfo::InfoTimezone)
  end

  def serialize(timezone)
    super({ 'zone' => ParamSerializers::Timezone.dump(timezone) })
  end

  def deserialize(hash)
    ParamSerializers::Timezone.load(hash.fetch('zone'))
  end
end
