class Scaler::Listener::BoshScaler
  class CfVarzProcessor
    attr_reader :buffers

    def initialize(buffer_size)
      @buffers = {}
      @buffer_size = buffer_size
    end

    def drop_missing_entities
      yesterday = Time.now - (60 * 60 * 24)
      @buffers.delete_if do |_, buffer|
        # cut off fractions
        buffer.first.timestamp.to_i < yesterday.to_i
      end
    end

    def process(event)
      return unless event.is_a? Scaler::CfVarzMetric

      @buffers["#{event.source_id}/#{event.key}"] ||= []
      buffer = @buffers["#{event.source_id}/#{event.key}"]
      # need ring buffer for better performance
      if buffer.size >= @buffer_size
        buffer.pop
      end
      buffer.unshift(event)
    end
  end
end
