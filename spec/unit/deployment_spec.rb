require 'spec_helper'

describe Scaler::Deployment do
  include_context 'default values'

  subject(:deployment) {
    Scaler::Deployment.new(YAML.load(base_manifest))
  }

  describe '#initialize' do
    it 'loads manifest and construct objects' do
      expect(deployment.name)
        .to eq('test')

      expect(deployment.jobs.keys)
        .to eq(%w{job0a job0b job1a job2a job2b})
      expect(deployment.resource_pools.keys)
        .to eq(%w{pool0 pool1 pool2})

      expect(deployment.resource_pool('pool0').jobs.keys)
        .to eq(%w{job0a job0b})
      expect(deployment.resource_pool('pool0').size)
        .to eq(3)
      expect(deployment.resource_pool('pool0').active_size)
        .to eq(3)
      expect(deployment.resource_pool('pool0').standby_size)
        .to eq(0)

      expect(deployment.resource_pool('pool1').jobs.keys)
        .to eq(%w{job1a})
      expect(deployment.resource_pool('pool1').size)
        .to eq(4)
      expect(deployment.resource_pool('pool1').active_size)
        .to eq(2)
      expect(deployment.resource_pool('pool1').standby_size)
        .to eq(2)
    end
  end

  describe '.load' do
    it 'loads manifest file in YAML format' do
      expect(Scaler::Deployment)
        .to receive(:new)
        .with(YAML.load(base_manifest))
      Scaler::Deployment.load_yaml(base_manifest)
    end
  end

  describe '#to_yaml' do
    it 'reflects updated values' do
      deployment.job('job0b').increase_size(702)
      deployment.job('job2a').increase_size_with_care(1)
      expect(YAML.load(deployment.to_yaml)).to eq(
        YAML.load(updated_manifest)
      )
      deployment.job('job0b').decrease_size(702)
      deployment.job('job2a').decrease_size_with_care(1)
      expect(YAML.load(deployment.to_yaml)).to eq(
        YAML.load(base_manifest)
      )
    end
  end
end
