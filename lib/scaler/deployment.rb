module Scaler
  class Deployment
    attr_reader :resource_pools
    attr_reader :jobs
    attr_reader :scale

    def initialize(manifest)
      @resource_pools = parse_resource_pools(manifest)

      @jobs = parse_jobs(manifest)
      calculate_standby_size(manifest)

      @scale = parse_scale(manifest)

      @manifest = manifest
    end

    def self.load_yaml(manifest)
      new(YAML.load(manifest))
    end

    def parse_resource_pools(manifest)
      result = {}
      manifest['resource_pools'].each do |definition|
        resource_pool = ResourcePool.new(self, definition)
        result[resource_pool.name] = resource_pool
      end
      result
    end

    def parse_jobs(manifest)
      result = {}
      manifest['jobs'].each do |hash|
        job = Job.new(self, hash)
        result[hash['name']] = job
        job.join_resorce_pool(resource_pool(hash['resource_pool']))
      end
      result
    end

    def parse_scale(manifest)
      Scale.new(manifest)
    end

    def calculate_standby_size(manifest)
      manifest['resource_pools'].each do |hash|
        pool = resource_pool(hash['name'])
        pool.standby_size = hash['size'] - pool.active_size
      end
    end

    def job(name)
      jobs[name]
    end

    def resource_pool(name)
      resource_pools[name]
    end

    def to_yaml
      @jobs.each { |_, o| o.apply_changes }
      @resource_pools.each { |_, o| o.apply_changes }
      @scale.apply_changes

      @manifest.to_yaml
    end
  end
end
