module Scaler
  class EventProcessor
    def initialize(listeners = [])
      @listeners = listeners
    end

    def add_listener(listener)
      @listeners << listener
    end

    def process(event)
      @listeners.each do |listener|
        listener.process(event)
      end
    end
  end
end
