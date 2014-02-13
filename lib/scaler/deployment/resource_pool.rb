module Scaler
  class Deployment
    class ResourcePool
      attr_reader :deployment
      attr_reader :name
      attr_accessor :standby_size

      def initialize(deployment, name)
        @deployment = deployment
        @name = name
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
    end
  end
end
