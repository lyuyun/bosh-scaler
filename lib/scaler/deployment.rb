module Scaler
  class Deployment
    attr_reader :resource_pools
    attr_reader :jobs

    def initialize(manifest)
      @resource_pools = parse_resource_pools(manifest)
      @jobs = parse_jobs(manifest)
      calculate_standby_size(manifest)

      @manifest = manifest
    end

    def self.load_yaml(manifest)
      new(YAML.load(manifest))
    end

    def parse_resource_pools(manifest)
      result = {}
      manifest['resource_pools'].each do |hash|
        result[hash['name']] = ResourcePool.new(self, hash['name'])
      end
      result
    end

    def parse_jobs(manifest)
      result = {}
      manifest['jobs'].each do |hash|
        job = Job.new(self, hash['name'], hash['instances'])
        result[hash['name']] = job
        job.join_resorce_pool(resource_pool(hash['resource_pool']))
      end
      result
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
      updated_manifest = @manifest.dup
      updated_manifest['jobs'].each do |manifest_job|
        manifest_job['instances'] = job(manifest_job['name']).size
      end
      updated_manifest['resource_pools'].each do |manifest_pool|
        manifest_pool['size'] = resource_pool(manifest_pool['name']).size
      end
      updated_manifest.to_yaml
    end
  end
end
