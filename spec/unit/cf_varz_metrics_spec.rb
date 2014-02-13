require 'spec_helper'

describe Scaler::CfVarzMetric do
  let(:now) { Time.now }
  let(:metric_data_base) {
    {
      'deployment' => 'koala',
      'job' => 'crown',
      'index' => 39,
      'timestamp' => now.to_i,
      'key' => 'koala.varz.key',
      'value' => 3939
    }
  }
  let(:metric_data) { metric_data_base }
  subject(:metric) { Scaler::CfVarzMetric.new(metric_data) }

  describe '#initialize' do
    it 'creates an object from given atrributes' do
      expect(metric.deployment).to eq('koala')
      expect(metric.job).to eq('crown')
      expect(metric.index).to eq(39)
      expect(metric.timestamp.to_i).to eq(now.to_i)
      expect(metric.key).to eq('koala.varz.key')
      expect(metric.value).to eq(3939)
      expect(metric.source_id).to eq('koala/crown/39')
    end

    context 'with a Time object' do
      let(:metric_data) { metric_data_base.merge('timestamp' => now) }
      it 'creates an object from given atrributes' do
        expect(metric.timestamp.to_i).to eq(now.to_i)
      end
    end
  end

  describe '#valid?' do
    def except(hash, *keys)
      keys.each { |key| hash.delete(key) }
      hash
    end

    context '@deployment is nil' do
      let(:metric_data) { except(metric_data_base, 'deployment') }
      it 'returns false' do
        expect(metric.valid?).to be false
      end
    end

    context '@job is nil' do
      let(:metric_data) { except(metric_data_base, 'job') }
      it 'returns false' do
        expect(metric.valid?).to be false
      end
    end

    context '@index is nil' do
      let(:metric_data) { except(metric_data_base, 'index') }
      it 'returns false' do
        expect(metric.valid?).to be false
      end
    end

    context '@key is nil' do
      let(:metric_data) { except(metric_data_base, 'key') }
      it 'returns false' do
        expect(metric.valid?).to be false
      end
    end

    context '@timestamp is nil' do
      let(:metric_data) { except(metric_data_base, 'timestamp') }
      it 'returns false' do
        expect(metric.valid?).to be false
      end
    end
  end
end
