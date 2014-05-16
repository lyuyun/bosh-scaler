require 'sinatra/base'
require 'thin'
require 'erb'

class Scaler::Listener::BoshScaler
  class Ui
    def initialize(scaler, port, logger)
      @scaler = scaler
      @logger = logger
      @port = port
    end

    def run
      scaler = @scaler
      logger = @logger
      http_server = Thin::Server.new('0.0.0.0', @port) do
        Thin::Logging.silent = true
        map '/' do
          run UiController.new(nil, scaler, logger)
        end
      end
      http_server.start!
    end

    class UiController < Sinatra::Base
      include ERB::Util

      def initialize(app, scaler, logger)
        super(app)
        @scaler = scaler
        @logger = logger
      end

      get '/' do
        ERB.new(
          File.read(File.join(File.dirname(__FILE__), 'ui', 'index.erb'))
        ).result(binding)
      end

      get '/log' do
        tasks = @scaler.bosh_client.fetch_tasks_recent
        tasks.delete_if do |task|
          task['user'] != @scaler.user
        end
        ERB.new(
          File.read(File.join(File.dirname(__FILE__), 'ui', 'log.erb'))
        ).result(binding)
      end
    end
  end
end
