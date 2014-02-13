module Scaler::Collector
  class BoshRestCollector
    def initialize(processor, logger, bosh_client, deployment_name, interval)
      @processor = processor
      @logger = logger
      @bosh_client = bosh_client
      @deployment_name = deployment_name
      @interval = interval
    end

    def self.load(processor, logger, options)
      new(
        processor,
        logger,
        Scaler::BoshClient.load(options['bosh_rest']),
        options['deployment'],
        options['interval']
      )
    end

    def run
      @logger.info('Starting BoshRestCollector...')
      EM.add_periodic_timer(@interval) do
        check_vitals
      end
      @logger.info('BoshRestCollector is running')
    end
  end

  def check_vitals
    # EM::http?
    @logger.debug('Fetching VMS vitals...')
    task = @bosh_client.fetch_vitals(@deployment_name)
    timer = EM.add_periodic_timer(1) do
      begin
        @logger.debug('Wating for VMS vitals task to be done...')
        task.update_state
        if task.state == 'done' || task.state == 'error'
          timer.cancel
          emit_event(task)
        end
      rescue
        # http error
        timer.cancel
        @logger.info('Failed to retrieve VM vitals task')
      end
    end
  rescue
    # http error
    @logger.info('Failed to retrieve VM vitals')
  end

  def emit_event(task)
    now = Time.new
    task.result.split("\n").each do |line|
      @logger.debug("Handling vital `#{line}`")
      data = Yajl::Parser.parse(line)
      data['job'] = data['job_name']
      data['timestamp'] = now.to_i
      data['deployment'] = @deployment_name
      event = Bosh::Monitor::Events::Heartbeat.new(data)
      @processor.process(event)
    end
  end
end
