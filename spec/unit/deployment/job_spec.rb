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

  describe '#add_static_ip' do
    subject(:job) {
      deployment.job('job2a')
    }

    it 'adds static ip got from scaling definition' do
      job.add_static_ip(1)
      expect(job.network('net00').static_ips.length)
        .to eq(3)
      expect(deployment.scale.network('net00').static_ips.length)
        .to eq(1)
    end

    it 'adds static multiple ips got from scaling definition' do
      job.add_static_ip(2)
      expect(job.network('net00').static_ips.length)
        .to eq(4)
      expect(deployment.scale.network('net00').static_ips.length)
        .to eq(0)
    end

    context 'ips are not available' do
      it 'fails' do
        expect {
          job.add_static_ip(3)
        }.to raise_error
      end
    end
  end

  describe '#remove_static_ip' do
    subject(:job) {
      deployment.job('job2a')
    }

    it 'removes static ip and pushes to scaling definition' do
      job.remove_static_ip(1)
      expect(job.network('net00').static_ips.length)
        .to eq(1)
      expect(deployment.scale.network('net00').static_ips.length)
        .to eq(3)
    end

    it 'removes static multiple ips got and pushes to scaling definition' do
      job.remove_static_ip(2)
      expect(job.network('net00').static_ips.length)
        .to eq(0)
      expect(deployment.scale.network('net00').static_ips.length)
        .to eq(4)
    end

    context 'static_ips are already empty' do
      it 'fails' do
        job.remove_static_ip(2)
        expect {
          job.remove_static_ip(1)
        }.to raise_error
      end
    end
  end

  describe '#increase_size_with_care' do
    subject(:job) {
      deployment.job('job2a')
    }

    it 'cares static ips' do
      expect(job).to receive(:increase_size).with(2)
      expect(job).to receive(:add_static_ip).with(2)
      job.increase_size_with_care(2)
    end

    context 'when the given number is beyond the limit' do
      subject(:job) {
        deployment.job('job2b')
      }

      it 'increases the size to the limit' do
        expect(job).to receive(:increase_size).with(5)
        expect(job).to receive(:add_static_ip).with(5)
        job.increase_size_with_care(10_000)
      end
    end
  end

  describe '#decrease_size_with_care' do
    subject(:job) {
      deployment.job('job2a')
    }

    it 'cares static ips' do
      expect(job).to receive(:decrease_size).with(2)
      expect(job).to receive(:remove_static_ip).with(2)
      job.decrease_size_with_care(2)
    end

    context 'when the given number is beyond the limit' do
      subject(:job) {
        deployment.job('job2b')
      }

      it 'decreases the size to the limit' do
        expect(job).to receive(:decrease_size).with(2)
        expect(job).to receive(:remove_static_ip).with(2)
        job.decrease_size_with_care(10_000)
      end
    end
  end
end
