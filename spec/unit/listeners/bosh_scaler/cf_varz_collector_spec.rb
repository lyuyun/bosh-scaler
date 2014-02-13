require 'spec_helper'

describe Scaler::Listener::BoshScaler::CfVarzProcessor do
  include_context 'default values'

  let(:processor) {
    Scaler::Listener::BoshScaler::CfVarzProcessor.new(5)
  }

  describe '#process' do
    it 'saves inbound Heartbeat events' do
      keep000 = Scaler::CfVarzMetric.new(
        'deployment' => 'keep0', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
        'timestamp' => Time.now.to_i
      )
      keep100 = Scaler::CfVarzMetric.new(
        'deployment' => 'keep1', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
        'timestamp' => Time.now.to_i
      )
      keep110 = Scaler::CfVarzMetric.new(
        'deployment' => 'keep1', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
        'timestamp' => Time.now.to_i
      )
      keep101 = Scaler::CfVarzMetric.new(
        'deployment' => 'keep1', 'job' => 'koala', 'index' => 0, 'key' => 'key1',
        'timestamp' => Time.now.to_i
      )

      processor.process(keep000)
      processor.process(keep100)
      processor.process(keep110)
      processor.process(keep101)

      expect(processor.buffers.keys)
        .to eq(['keep0/koala/0/key0', 'keep1/koala/0/key0', 'keep1/koala/0/key1'])
      expect(processor.buffers['keep0/koala/0/key0'][0]).to eq(keep000)
      expect(processor.buffers['keep1/koala/0/key0'][0]).to eq(keep110)
      expect(processor.buffers['keep1/koala/0/key0'][1]).to eq(keep100)
      expect(processor.buffers['keep1/koala/0/key1'][0]).to eq(keep101)
    end

    it 'drops old events from buffers' do
      10.times do
        processor.process(
          Scaler::CfVarzMetric.new(
            'deployment' => 'keep0',
            'job' => 'koala',
            'index' => 0,
            'key' => 'key0',
            'timestamp' => Time.now.to_i
          )
        )
      end

      expect(processor.buffers['keep0/koala/0/key0'].size).to eq(5)
    end
  end

  describe '#drop_missing_entities' do
    it 'deletes old entities from the buffer' do
      now = Time.now
      time_on_threshold = now - (60 * 60 * 24)
      time_to_be_deleted = now - (60 * 60 * 24) - 1

      processor.process(
        Scaler::CfVarzMetric.new(
          'deployment' => 'keep0', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
          'timestamp' => now.to_i
        )
      )
      processor.process(
        Scaler::CfVarzMetric.new(
          'deployment' => 'keep1', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
          'timestamp' => time_on_threshold.to_i
        )
      )
      processor.process(
        Scaler::CfVarzMetric.new(
            'deployment' => 'keep2', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
            'timestamp' => time_to_be_deleted.to_i
        )
      )
      processor.process(
        Scaler::CfVarzMetric.new(
          'deployment' => 'keep2', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
          'timestamp' => now.to_i
        )
      )
      processor.process(
        Scaler::CfVarzMetric.new(
          'deployment' => 'remove0', 'job' => 'koala', 'index' => 0, 'key' => 'key0',
          'timestamp' => time_to_be_deleted.to_i
        )
      )

      allow(Time).to receive(:now).and_return(now)

      processor.drop_missing_entities

      expect(processor.buffers.keys).to eq(
        ['keep0/koala/0/key0', 'keep1/koala/0/key0', 'keep2/koala/0/key0'])
    end
  end
end
