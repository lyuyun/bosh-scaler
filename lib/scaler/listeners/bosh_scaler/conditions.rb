class Scaler::Listener::BoshScaler
  module Condition
    class Base
      def initialize(processor, deployment_name, job_name, threshold_proc)
        @processor = processor
        @deployment_name = deployment_name
        @job_name = job_name
        @threshold_proc = threshold_proc
      end

      def self.load(processors, deployment_name, job_name, options)
        new(
          select_processor(processors),
          deployment_name,
          job_name,
          create_threshold_proc(options))
      end

      def self.select_processor(processors)
        processor = processors.find { |proc| proc.is_a?(processor_class) }
        if processor.nil?
          fail 'No compatible processor found'
        end
        processor
      end

      def self.processor_class
        fail 'Not implemented'
      end

      def self.create_threshold_proc(options)
        if options.key?('larger_than')
          proc = proc { |value| value > options['larger_than'] }
        elsif options.key?('smaller_than')
          proc = proc { |value| value < options['smaller_than'] }
        else
          fail 'No condition given'
        end
        proc
      end

      def match
        fail 'Not implemented'
      end
    end

    class DurationAverageConditionBase < Base
      def initialize(processor, deployment_name, job_name, threshold_proc, duration)
        super(processor, deployment_name, job_name, threshold_proc)
        @duration = duration
      end

      def self.load(processors, deployment_name, job_name, options)
        new(
          select_processor(processors),
          deployment_name,
          job_name,
          create_threshold_proc(options),
          options['duration'])
      end

      def self.processor_class
        Scaler::Listener::BoshScaler::HeartbeatProcessor
      end

      def match
        cutoff_time = Time.now - @duration
        usage_total = 0.0
        usage_num = 0

        @processor.buffers.each do |_, entity_buffer|
          entity_buffer.each do |metric|
            break if metric[:timestamp] <= cutoff_time.to_i
            break if metric[:deployment] != @deployment_name || metric[:job] != @job_name

            usage_total += sample(metric)
            usage_num += 1
          end
        end

        @threshold_proc.call(usage_total / usage_num)
      end

      def sample(metric)
        fail 'Not implemented'
      end
    end

    class CpuAverageCondition < DurationAverageConditionBase
      def sample(metric)
        metric[:vitals]['cpu']['user'].to_f +
          metric[:vitals]['cpu']['sys'].to_f +
          metric[:vitals]['cpu']['wait'].to_f
      end
    end

    class MemoryAverageCondition < DurationAverageConditionBase
      def sample(metrics)
        metric[:vitals]['mem']['percent'].to_f
      end
    end

    class CfVarzAverageCondition < DurationAverageConditionBase
      def initialize(
          processor, deployment_name, job_name, threshold_proc,
          duration, varz_job_name, varz_key)
        super(processor, deployment_name, job_name, threshold_proc, duration)
        @varz_job_name = varz_job_name
        @varz_key = varz_key
      end

      def self.load(processors, deployment_name, job_name, options)
        new(
          select_processor(processors),
          deployment_name,
          job_name,
          create_threshold_proc(options),
          options['duration'],
          options['varz_job'],
          options['varz_key'])
      end

      def self.processor_class
        Scaler::Listener::BoshScaler::CfVarzProcessor
      end

      def match
        cutoff_time = Time.now - @duration
        usage_total = 0.0
        usage_num = 0

        @processor.buffers.each do |_, entity_buffer|
          entity_buffer.each do |metric|
            break if metric.timestamp <= cutoff_time
            break if metric.deployment != @deployment_name ||
              metric.job != @varz_job_name ||
              metric.key != @varz_key

            usage_total += sample(metric)
            usage_num += 1
          end
        end

        @threshold_proc.call(usage_total / usage_num)
      end

      def sample(metric)
        metric.value
      end
    end

    class LastSampleConditionBase < Base
      def match
        usage_total = 0.0
        usage_num = 0

        @processor.buffers.each do |_, entity_buffer|
          metric = entity_buffer.first
          next if metric[:deployment] != @deployment_name || metric[:job] != @job_name

          usage_total += sample(metric)
          usage_num += 1
        end

        @threshold_proc.call(usage_total / usage_num)
      end

      def self.processor_class
        Scaler::Listener::BoshScaler::HeartbeatProcessor
      end

      def sample(metric)
        fail 'Not implemented'
      end
    end

    class LoadAverage1Condition < LastSampleConditionBase
      def sample(metric)
        metric[:vitals]['load'][0].to_f
      end
    end

    class LoadAverage5Condition < LastSampleConditionBase
      def sample(metric)
        metric[:vitals]['load'][1].to_f
      end
    end

    class LoadAverage15Condition < LastSampleConditionBase
      def sample(metric)
        metric[:vitals]['load'][2].to_f
      end
    end
  end
end
