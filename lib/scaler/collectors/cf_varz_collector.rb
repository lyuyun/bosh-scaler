require 'sinatra/base'
require 'thin'

module Scaler::Collector
  class CfVarzCollector
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
      processor = @processor
      logger = @logger

      http_server = Thin::Server.new('0.0.0.0', @port) do
        Thin::Logging.silent = true
        map '/' do
          run ApiController.new(nil, processor, logger)
        end
      end

      http_server.start!
    end

    class ApiController < Sinatra::Base
      def initialize(app, processor, logger)
        super(app)
        @processor = processor
        @logger = logger
      end

      put '/metrics/:key/values' do
        @logger.debug("Handling Massage `#{request.body.read}` about `#{params[:key]}`")
        request.body.rewind
        attributes = Yajl::Parser.parse(request.body.read)
        attributes['key'] = params[:key]
        attributes['timestamp'] = Time.now.to_i
        @processor.process(Scaler::CfVarzMetric.new(attributes))
        'ok'
      end
    end
  end
end
