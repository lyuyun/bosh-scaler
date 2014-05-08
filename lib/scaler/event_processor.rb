module Scaler
  class EventProcessor
    def initialize(listeners = [], logger)
      @listeners = listeners
      @logger = logger
      @counter = 0
    end

    def run
      EM.add_periodic_timer(10) do
        @logger.debug("Processed #{@counter} events in 10 secs")
        @counter = 0
      end
    end

    def add_listener(listener)
      @listeners << listener
    end

    def process(event)
      @counter += 1
      @listeners.each do |listener|
        listener.process(event)
      end
    end
  end
end
