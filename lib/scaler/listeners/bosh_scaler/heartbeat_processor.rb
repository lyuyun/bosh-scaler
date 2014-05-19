class Scaler::Listener::BoshScaler
  class HeartbeatProcessor
    attr_reader :buffers

    def initialize(buffer_size)
      @buffers = {}
      @buffer_size = buffer_size
    end

    def drop_missing_entities
      yesteray = Time.now - (60 * 60 * 24)
      @buffers.delete_if do |_, buffer|
        buffer.first[:timestamp] < yesteray.to_i
      end
    end

    def process(event)
      return unless event.is_a? Bosh::Monitor::Events::Heartbeat

      @buffers[event.agent_id] ||= []
      buffer = @buffers[event.agent_id]
      # need ring buffer for better performance
      if buffer.size >= @buffer_size
        buffer.pop
      end
      buffer.unshift(event.to_hash)
    end

    def updated_time(buffer_name)
      Time.at(@buffers[buffer_name].first[:timestamp])
    end
  end
end
