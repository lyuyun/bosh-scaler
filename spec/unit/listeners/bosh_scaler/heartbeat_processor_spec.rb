require 'spec_helper'

describe Scaler::Listener::BoshScaler::HeartbeatProcessor do
  include_context 'default values'

  subject(:processor) {
    Scaler::Listener::BoshScaler::HeartbeatProcessor.new(5)
  }

  describe '#process' do
    it 'saves inbound Heartbeat events' do
      keep00 = Bosh::Monitor::Events::Heartbeat.new(
        'agent_id' => 'keep0', 'timestamp' => Time.now.to_i
      )
      keep10 = Bosh::Monitor::Events::Heartbeat.new(
        'agent_id' => 'keep1', 'timestamp' => Time.now.to_i
      )
      keep11 = Bosh::Monitor::Events::Heartbeat.new(
        'agent_id' => 'keep1', 'timestamp' => Time.now.to_i
      )

      processor.process(keep00)
      processor.process(keep10)
      processor.process(keep11)

      expect(processor.buffers.keys).to eq(%w(keep0 keep1))
      expect(processor.buffers['keep0'][0]).to eq(keep00.to_hash)
      expect(processor.buffers['keep1'][0]).to eq(keep11.to_hash)
      expect(processor.buffers['keep1'][1]).to eq(keep10.to_hash)
    end

    it 'drops old events from buffers' do
      10.times do
        processor.process(
          Bosh::Monitor::Events::Heartbeat.new(
             'agent_id' => 'keep0', 'timestamp' => Time.now.to_i
          )
        )
      end

      expect(processor.buffers['keep0'].size).to eq(5)
    end
  end

  describe '#drop_missing_entities' do
    it 'deletes old entities from the buffer' do
      now = Time.now
      time_on_threshold = now - (60 * 60 * 24)
      time_to_be_deleted = now - (60 * 60 * 24) - 1

      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'agent_id' => 'keep0', 'timestamp' => now.to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'agent_id' => 'keep1', 'timestamp' => time_on_threshold.to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'agent_id' => 'keep2', 'timestamp' => time_to_be_deleted.to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'agent_id' => 'keep2', 'timestamp' => now.to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'agent_id' => 'remove0', 'timestamp' => time_to_be_deleted.to_i
        )
      )

      allow(Time).to receive(:now).and_return(now)

      processor.drop_missing_entities

      expect(processor.buffers.keys).to eq(%w(keep0 keep1 keep2))
    end
  end

end
