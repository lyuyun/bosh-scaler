module Scaler
  class Deployment
    class Job
      attr_reader :deployment
      attr_reader :name
      attr_accessor :size
      attr_reader :resource_pool
      attr_reader :networks

      def initialize(deployment, definition)
        @deployment = deployment
        @definition = definition
        @name = definition['name'].dup
        @size = definition['instances']

        if definition['networks']
          @networks = {}
          definition['networks'].each do |network_definition|
            network = Network.new(network_definition)
            @networks[network.name] = network
          end
        end

        @resource_pool = nil
      end

      def join_resorce_pool(resource_pool)
        if resource_pool.deployment != deployment
          fail 'Mixing Resouce Pools and Jobs from different deployments is not allowed'
        end
        unless @resource_pool.nil?
          fail "Rejoining from Resource Pool `#{resource_pool.name}` to another Resource Pool is not allowed (Job: #{name})"
        end

        @resource_pool = resource_pool
      end

      def increase_size(num)
        @size = @size + num
      end

      def decrease_size(num)
        @size = size - num
        if @size < 0
          fail 'Setting a negative number to Job size is not allowed'
        end
      end

      def add_static_ip(num)
        (@networks || []).each do |_, network|
          if network.static_ips_defined?
            scale_network = @deployment.scale.network(network.name)
            num.times do
              ip = scale_network.pop_static_ip
              network.add_static_ip(ip)
            end
          end
        end
      end

      def remove_static_ip(num)
        (@networks || []).each do |_, network|
          if network.static_ips_defined?
            scale_network = @deployment.scale.network(network.name)
            num.times do
              ip = network.remove_static_ip
              scale_network.push_static_ip(ip)
            end
          end
        end
      end

      def increase_size_with_care(num)
        scale_job = @deployment.scale.job(@name)
        if scale_job
          limit = scale_job.out_limit
          if @size + num > limit
            num = limit - @size
          end
        end

        increase_size(num)
        add_static_ip(num)
      end

      def decrease_size_with_care(num)
        scale_job = @deployment.scale.job(@name)
        if scale_job
          limit = scale_job.in_limit
          if @size - num < limit
            num = @size - limit
          end
        end

        decrease_size(num)
        remove_static_ip(num)
      end

      def network(name)
        @networks[name]
      end

      def apply_changes
        unless @networks.nil?
          @networks.each { |_, o| o.apply_changes }
        end
        @definition['instances'] = @size
      end
    end

    class Network
      attr_reader :name
      attr_reader :static_ips

      def initialize(definition)
        @definition = definition
        @name = definition['name'].dup

        if definition['static_ips']
          @static_ips = definition['static_ips'].dup
        end
      end

      def static_ips_defined?
        # empty array returns true
        ! @static_ips.nil?
      end

      def add_static_ip(ip)
        fail if @static_ips.nil?
        @static_ips.push(ip)
      end

      def remove_static_ip
        fail if @static_ips.nil?
        fail if @static_ips.empty?
        @static_ips.pop
      end

      def apply_changes
        if @static_ips
          @definition['static_ips'] = @static_ips.dup
        end
      end
    end
  end
end
