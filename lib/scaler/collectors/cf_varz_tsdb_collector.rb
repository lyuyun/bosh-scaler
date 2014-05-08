module Scaler::Collector
  class CfVarzTsdbCollector
    class TsdbServer < EM::Connection
      include EM::Protocols::LineText2

      def initialize(logger, collector)
        @logger = logger
        @collector = collector
      end

      def post_init
        @logger.info('New connection to TSDB server initialized')
      end

      def receive_line(line)
        # for easier test
        @collector.receive_line(line)
      end

      def unbind
        @logger.info('Connection to TSDB server closed')
      end
    end

    def initialize(processor, logger, port)
      @processor = processor
      @logger = logger
      @port = port
    end

    def self.load(processor, logger, options)
      new(
        processor,
        logger,
        options['port']
      )
    end

    def run
      @logger.info('Starting CfVarzTsdbCollector...')
      EventMachine.start_server '0.0.0.0', @port, TsdbServer, @logger, self
    end

    def receive_line(line)
      attributes = {}
      elements = line.split(' ')

      elements.shift # 'put' command

      attributes['key'] = elements.shift

      # Do not use original timestamp, we manage time on my own
      elements.shift
      attributes['timestamp'] = Time.now.to_i

      raw_value = elements.shift
      if raw_value.include?('.')
        attributes['value'] = raw_value.to_f
      else
        attributes['value'] = raw_value.to_i
      end

      elements.each do |element|
        pair = element.split('=')
        attributes[pair[0]] = pair[1]
      end

      @processor.process(Scaler::CfVarzMetric.new(attributes))
    rescue => e
      @logger.error("Error in CfVarzTsdbCollector: #{e}")
    end
  end
end
