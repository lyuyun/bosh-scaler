module Scaler::Collector
  class BoshNatsCollector
    def initialize(processor, logger, nats_client_options, bosh_client)
      @processor = processor
      @logger = logger
      @nats_client_options = nats_client_options
      @bosh_client = bosh_client
      @deployments = {}
    end

    def self.load(processor, logger, options)
      new(
        processor,
        logger,
        options['bosh_nats']
          .each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
          .merge(:autostart => false),
        Scaler::BoshClient.load(options['bosh_rest'])
      )
    end

    def run
      @logger.info('Starting BoshNatsCollector...')
      sync_deployments

      nats = connect_to_mbus
      nats.subscribe('hm.agent.heartbeat.*') do |message, reply, subject|
        handle_heartbeat(message, subject)
      end

      @logger.info('BoshNatsCollector is running')
    end

    def sync_deployments
      @logger.debug('Syncing deployments information...')
      @deployments = {}
      begin
        deployments = @bosh_client.fetch_deployments
        deployments.each do |deployment|
          vms = @bosh_client.fetch_agents(deployment['name'])
          vms.each do |vm|
            @deployments[vm['agent_id']] = deployment['name']
          end
        end
      rescue
        # HTTP errr
        @logger.error('Synchronizing deplyoment error')
      end
      @logger.debug('Syncing deployments information done')
    end

    def connect_to_mbus
      nats = NATS.connect(@nats_client_options) do
        @logger.info("NATS connected to #{@nats_client_options[:uri]}")
      end
      nats.on_error do |e|
        # TODO
      end
      nats
    end

    def handle_heartbeat(message, subject)
      @logger.debug("Handling Massage `#{message}` from `#{subject}`")
      attributes = Yajl::Parser.parse(message)
      agent_id = subject.split('.', 4).last

      unless @deployments.key?(agent_id)
        @logger.debug("BOSH Agent `#{agent_id}` is not found in the cache")
        sync_deployments
      end

      attributes['timestamp'] = Time.now.to_i
      attributes['agent_id'] = agent_id
      attributes['deployment'] = @deployments[agent_id]

      @processor.process(Bosh::Monitor::Events::Heartbeat.new(attributes))
    end
  end
end
