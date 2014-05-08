module Scaler
  class Runner
    def self.run(config_file_path)
      new(
        YAML.load(
          File.read(
            File.expand_path(config_file_path)))).start
    end

    attr_reader :logger

    def initialize(config)
      @config = config

      output = STDOUT
      level = Logger::DEBUG
      if config.key?('logging')
        log_config = config['logging']
        if log_config.key?('file')
          output = File.expand_path(log_config['file'])
        end
        if log_config.key?('level')
          level = Logger.const_get(log_config['level'].upcase)
        end
      end
      @logger = Logger.new(output)
      @logger.level = level
    end

    def start
      Bhm.logger = @logger
      @logger.info('Starting...')

      initialize_listeners
      processor = EventProcessor.new(@listeners, @logger)
      initialize_collectors(processor)

      EM.epoll
      EM.kqueue
      EM.run do
        setup_signals
        processor.run
        run_listeners
        run_collectors
      end

      self
    end

    def initialize_listeners
      @listeners = []
      @config['listeners'].each do |listener_config|
        klass = Scaler::Listener.const_get(listener_config['class'])
        @listeners << klass.new(listener_config)
      end
    end

    def initialize_collectors(event_processor)
      @collectors = []
      @config['collectors'].each do |collector_config|
        klass = Scaler::Collector.const_get(collector_config['class'])
        @collectors << klass.load(event_processor, @logger, collector_config)
      end
    end

    def run_listeners
      @listeners.each(&:run)
    end

    def run_collectors
      @collectors.each(&:run)
    end

    def setup_signals
      Signal.trap('INT') { EM.stop }
      Signal.trap('TERM') { EM.stop }
    end
  end
end
