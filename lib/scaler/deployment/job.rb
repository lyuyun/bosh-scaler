module Scaler
  class Deployment
    class Job
      attr_reader :deployment
      attr_reader :name
      attr_accessor :size
      attr_reader :resource_pool

      def initialize(deployment, name, size)
        @deployment = deployment
        @name = name
        @size = size

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
    end
  end
end
