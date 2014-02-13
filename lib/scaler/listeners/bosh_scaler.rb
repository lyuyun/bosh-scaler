module Scaler::Listener
  class BoshScaler < Bosh::Monitor::Plugins::Base
    def initialize(options = {})
      @buffer_size = options['buffer_size']
      @interval = options['interval']
      @bosh_client = Scaler::BoshClient.load(options['bosh_rest'])
      setup_processors(options)
      load_rules(options)
      super
    end

    def load_rules(options)
      @rules = options['rules']
      @rules.each do |rule|
        rule['last_fired_time'] = Time.new(0)
        rule['out']['condition'] =
          self.class::Condition
            .const_get(rule['out']['condition']['class'] + 'Condition').load(
              @processers,
              rule['deployment'],
              rule['job'],
              rule['out']['condition']
            )
        rule['in']['condition'] =
          self.class::Condition
            .const_get(rule['in']['condition']['class'] + 'Condition').load(
              @processers,
              rule['deployment'],
              rule['job'],
              rule['in']['condition']
            )
      end
    end

    def setup_processors(options)
      @processers = []
      @processers << HeartbeatProcessor.new(@buffer_size)
      @processers << CfVarzProcessor.new(@buffer_size)
    end

    def run
      logger.info('Starting BOSH Scaler...')
      unless EM.reactor_running?
        logger.error('BOSH Scaler can only be started when event loop is running')
        return false
      end

      EM.add_periodic_timer(@interval) do
        try_rules
      end
      EM.add_periodic_timer(60 * 60 * 24) do
        @processers.each do |processor|
          processor.drop_missing_entities
        end
      end
      logger.info('Starting BOSH Scaler is running')
    end

    def try_rules
      logger.debug('Searching matched rules...')
      deployment_matched_rules = extract_condition_matched_rules

      deployment_matched_rules.each do |deployment_name, matched_rules|
        next if matched_rules[:out].empty? && matched_rules[:in].empty?
        manifest = @bosh_client.fetch_deployment_manifest(deployment_name)
        deployment = Scaler::Deployment.load_yaml(manifest)

        rules_to_execute = drop_size_mismatched_rules(matched_rules, deployment)

        next if rules_to_execute.empty?

        if @bosh_client.processing_deployment?
          logger.info('Another deployment is under processing...')
          next
        end

        manifest = deployment.to_yaml
        logger.info("Deploying manifest: #{manifest}")
        @bosh_client.deploy(manifest)
        now = Time.now
        rules_to_execute.each do |rule|
          rule['last_fired_time'] = now
        end
      end
    end

    def extract_condition_matched_rules
      now = Time.now
      result = {}
      @rules.each do |rule|
        next if rule['last_fired_time'] > now - rule['cooldown']

        result[rule['deployment']] ||= { :out => [], :in => [] }
        if rule['out']['condition'].match
          result[rule['deployment']][:out] << rule
          next # out has priority
        end
        if rule['in']['condition'].match
          result[rule['deployment']][:in] << rule
        end
      end
      result
    end

    def drop_size_mismatched_rules(rules, deployment)
      result = []

      rules[:out].each do |rule|
        if deployment.job(rule['job']).size < rule['out']['limit']
          deployment.job(rule['job']).increase_size(1)
          result << rule
        end
      end

      rules[:in].each do |rule|
        if deployment.job(rule['job']).size > rule['in']['limit']
          deployment.job(rule['job']).decrease_size(1)
          result << rule
        end
      end

      result
    end

    def process(event)
      @processers.each do |processor|
        processor.process(event)
      end
    end
  end
end
