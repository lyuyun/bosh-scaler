module Scaler
  class Deployment
    class ResourcePool
      attr_reader :deployment
      attr_reader :name
      attr_accessor :standby_size

      def initialize(deployment, definition)
        @deployment = deployment
        @definition = definition
        @name = definition['name'].dup
        @standby_size = 0
      end

      def jobs
        deployment.jobs.select { |_, job| job.resource_pool == self }
      end

      def size
        active_size + standby_size
      end

      def active_size
        jobs.values.reduce(0) { |sum, job| sum + job.size }
      end

      def apply_changes
        @definition['size'] = size
      end
    end
  end
end
