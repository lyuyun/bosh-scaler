module Scaler::Listener
  class BoshScaler < Bosh::Monitor::Plugins::Base
    def initialize(options = {})
      @buffer_size = options['buffer_size']
      @interval = options['interval']
      @bosh_client = Scaler::BoshClient.load(options['bosh_rest'])
      setup_processors(options)
      super
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

      update_rules
      EM.add_periodic_timer(60) do
        update_rules
      end

      EM.add_periodic_timer(@interval) do
        try_rules
      end
      EM.add_periodic_timer(60 * 60 * 24) do
        @processers.each do |processor|
          processor.drop_missing_entities
        end
      end
      logger.info('BOSH Scaler is running')
    end

    def update_rules
      logger.debug('Syncing rules...')
      old_rules = @rules || {}
      @rules = {}
      now = Time.now

      deployments = @bosh_client.fetch_deployments
      deployments.each do |deployment_info|
        deployment_name = deployment_info['name']
        @rules[deployment_name] = {}
        manifest = @bosh_client.fetch_deployment_manifest(deployment_name)
        deployment = Scaler::Deployment.load_yaml(manifest)

        deployment.scale.jobs.each do |_, job|
          job_config = {
            :name => job.name,
            :cooldown_time => job.cooldown_time,
            :last_fired_time => now,
            :out_limit => job.out_limit,
            :in_limit => job.in_limit,
            :out_unit => job.out_unit,
            :in_unit => job.in_unit,
            :out_conditions => [],
            :in_conditions => []
          }
          @rules[deployment_name][job.name] = job_config

          job.out_conditions.each do |condition|
            job_config[:out_conditions].push(
              self.class::Condition
                .load_by_definition(@processers, deployment_name, job.name, condition)
            )
          end

          job.in_conditions.each do |condition|
            job_config[:in_conditions].push(
              self.class::Condition
                .load_by_definition(@processers, deployment_name, job.name, condition)
            )
          end

          if old_rules.key?(deployment_name) &&
              old_rules[deployment_name].key?(job.name)
            job_config[:last_fired_time] =
              old_rules[deployment_name][job.name][:last_fired_time]
          end
        end
        logger.debug("Loaded rules for `#{deployment.scale.jobs.keys.join(' ')}` in #{deployment_name}")
      end
    end

    def try_rules
      logger.debug('Searching matched rules...')
      jobs_to_scale = search_jobs_to_scale

      jobs_to_scale.each do |deployment_name, matched_jobs|
        next if matched_jobs[:out].empty? && matched_jobs[:in].empty?

        manifest = @bosh_client.fetch_deployment_manifest(deployment_name)
        deployment = Scaler::Deployment.load_yaml(manifest)

        begin
          processed_jobs = update_deployment(matched_jobs, deployment)
        rescue => e
          logger.error("Updating deployment manifest of #{deployment_name} failed: #{e}")
          next
        end

        next if processed_jobs.empty?

        if @bosh_client.processing_deployment?
          logger.info('Another deployment is under processing...')
          next
        end

        manifest = deployment.to_yaml
        logger.info("Deploying manifest: #{manifest}")
        @bosh_client.deploy(manifest)
        now = Time.now
        processed_jobs.each do |job|
          job[:last_fired_time] = now
        end
      end
    end

    def search_jobs_to_scale
      now = Time.now
      result = {}

      @rules.each do |deployment_name, jobs|
        result[deployment_name] = { :out => [], :in => [] }

        jobs.each do |_, job|
          next if job[:last_fired_time] > now - job[:cooldown_time]

          # If :out_conditions matches, skip evaluating :in_conditions
          # Scaling out has the priority
          # currently scaling-out conditions are joined with OR
          next unless job[:out_conditions].each do |condition|
            if condition.match
              result[deployment_name][:out] << job
              break
            end
          end

          # currently scaling-in conditions are joined with AND
          in_results = job[:in_conditions].map do |condition|
            condition.match
          end
          if in_results.delete(false).nil?
            result[deployment_name][:in] << job
          end

        end
      end

      result
    end

    def update_deployment(jobs, deployment)
      processed_jobs = []

      jobs[:out].each do |job|
        if deployment.job(job[:name]).size < job[:out_limit]
          unit = job[:out_unit] || 1
          deployment.job(job[:name]).increase_size_with_care(unit)
          processed_jobs << job
        end
      end

      jobs[:in].each do |job|
        if deployment.job(job[:name]).size > job[:in_limit]
          unit = job[:in_unit] || 1
          deployment.job(job[:name]).decrease_size_with_care(unit)
          processed_jobs << job
        end
      end

      processed_jobs
    end

    def process(event)
      @processers.each do |processor|
        processor.process(event)
      end
    end
  end
end
