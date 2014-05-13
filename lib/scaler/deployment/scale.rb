module Scaler
  class Deployment
    class Scale
      attr_reader :jobs
      attr_reader :networks

      def initialize(manifest)
        @definition = manifest['scale'] || {}

        @jobs = parse_jobs
        @networks = parse_networks
      end

      def parse_jobs
        results = {}
        unless @definition['jobs'].nil?
          @definition['jobs'].map do |v|
            results[v['name']] = Job.new(v)
          end
        end
        results
      end

      def parse_networks
        results = {}
        unless @definition['networks'].nil?
          @definition['networks'].map do |v|
            results[v['name']] = Network.new(v)
          end
        end
        results
      end

      def job(name)
        jobs[name]
      end

      def network(name)
        networks[name]
      end

      def apply_changes
        @jobs.each { |_, o| o.apply_changes }
        @networks.each { |_, o| o.apply_changes }
      end
    end
  end
end

module Scaler
  class Deployment
    class Scale
      class Job
        attr_reader :name
        attr_reader :cooldown_time
        attr_reader :out_limit
        attr_reader :in_limit
        attr_reader :out_unit
        attr_reader :in_unit
        attr_reader :out_conditions
        attr_reader :in_conditions

        def initialize(definition)
          @definition = definition

          @name = definition['name'].dup
          @cooldown_time = definition['cooldown']
          @out_conditions = []
          @in_conditions = []

          if definition['out']
            @out_limit = definition['out']['limit']
            @out_unit = definition['out']['unit']
            @out_conditions = definition['out']['conditions']
          end
          if definition['in']
            @in_limit = definition['in']['limit']
            @in_unit = definition['in']['unit']
            @in_conditions = definition['in']['conditions']
          end
        end

        def apply_changes
        end
      end
    end
  end
end

module Scaler
  class Deployment
    class Scale
      class Network
        attr_reader :name
        attr_reader :static_ips

        def initialize(definition)
          @definition = definition
          @name = definition['name'].dup
          if definition.key?('static_ips')
            @static_ips = definition['static_ips'].dup
          end
        end

        def pop_static_ip
          if static_ips.size > 0
            @static_ips.pop
          else
            fail Error('No static IP address available')
          end
        end

        def push_static_ip(ip)
          @static_ips ||= []
          @static_ips.push(ip)
        end

        def apply_changes
          unless @static_ips.nil?
            @definition['static_ips'] = @static_ips.dup
          end
        end
      end
    end
  end
end
