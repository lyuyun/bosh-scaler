require 'spec_helper'

describe Scaler::Deployment::Job do
  include_context 'default values'

  let(:deployment) {
    Scaler::Deployment.new(YAML.load(base_manifest))
  }

  subject(:job) {
    deployment.job('job0a')
  }

  describe '#increase_size' do
    it 'adds job size' do
      job.size = 39
      job.increase_size(3900)
      expect(job.size).to eq(3939)
    end
  end

  describe '#decrease_size' do
    it 'subtracts job size' do
      job.size = 40
      job.decrease_size(1)
      expect(job.size).to eq(39)
    end

    it 'raises error when the size goes negative' do
      job.size = 0
      expect { job.decrease_size(1) }
        .to raise_error('Setting a negative number to Job size is not allowed')
    end
  end
end
