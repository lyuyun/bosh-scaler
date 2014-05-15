require 'spec_helper'

describe Scaler::Listener::BoshScaler::Condition::Base do
  describe '.create_threshold' do
    it 'generates a proc object from a `larger_than` value' do
      threshold = Scaler::Listener::BoshScaler::Condition::Base
        .create_threshold('larger_than' => 39)
      expect(threshold[:proc].call(39)).to be false
      expect(threshold[:proc].call(40)).to be true
      expect(threshold[:name]).to eq('larger than')
    end

    it 'generates a proc object from a `smaller_than` value' do
      threshold = Scaler::Listener::BoshScaler::Condition::Base
        .create_threshold('smaller_than' => 39)
      expect(threshold[:proc].call(39)).to be false
      expect(threshold[:proc].call(38)).to be true
      expect(threshold[:name]).to eq('smaller than')
    end
  end
end

describe Scaler::Listener::BoshScaler::Condition::DurationAverageConditionBase do
  describe '#match' do
    it 'choose correct buffers to sample' do
      now = Time.now

      event00 = Bosh::Monitor::Events::Heartbeat.new(
        'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent0',
        'timestamp' => (now - 9).to_i
      )
      event01 = Bosh::Monitor::Events::Heartbeat.new(
        'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent0',
        'timestamp' => now.to_i
      )
      event02 = Bosh::Monitor::Events::Heartbeat.new(
        'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent1',
        'timestamp' => (now - 40).to_i
      )
      event03 = Bosh::Monitor::Events::Heartbeat.new(
        'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent1',
        'timestamp' => now.to_i
      )

      processor = Scaler::Listener::BoshScaler::HeartbeatProcessor.new(1000)
      processor.process(event00)
      processor.process(event01)
      processor.process(event02)
      processor.process(event03)

      # metrics to be skipped
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'skip0',
          'timestamp' => (now - 59).to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'deployment' => 'deployment1', 'job' => 'job0', 'agent_id' => 'skip1',
          'timestamp' => now.to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'deployment' => 'deployment0', 'job' => 'job1', 'agent_id' => 'skip2',
          'timestamp' => now.to_i
        )
      )

      threshold = { :proc => instance_double(Proc) }
      condition = Scaler::Listener::BoshScaler::Condition::DurationAverageConditionBase
        .new(processor, 'deployment0', 'job0', threshold, 10)

      expect(condition).to receive(:sample).with(event00.to_hash).and_return(1)
      expect(condition).to receive(:sample).with(event01.to_hash).and_return(1)
      expect(condition).to receive(:sample).with(event03.to_hash).and_return(1)

      expect(threshold[:proc]).to receive(:call).with(1)

      condition.match
    end
  end
end

describe Scaler::Listener::BoshScaler::Condition::LastSampleConditionBase do
  describe '#match' do
    it 'choose correct buffers to sample' do
      event00 = Bosh::Monitor::Events::Heartbeat.new(
         'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent0 ')
      event01 = Bosh::Monitor::Events::Heartbeat.new(
         'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent0 ')
      event02 = Bosh::Monitor::Events::Heartbeat.new(
         'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent1 ')
      event03 = Bosh::Monitor::Events::Heartbeat.new(
         'deployment' => 'deployment0', 'job' => 'job0', 'agent_id' => 'agent1 ')

      processor = Scaler::Listener::BoshScaler::HeartbeatProcessor.new(1000)
      processor.process(event00)
      processor.process(event01)
      processor.process(event02)
      processor.process(event03)

      # metrics to be skipped
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
           'deployment' => 'deployment1', 'job' => 'job0', 'agent_id' => 'skip1 '))
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
           'deployment' => 'deployment0', 'job' => 'job1', 'agent_id' => 'skip2 '))

      threshold = { :proc => instance_double(Proc) }
      condition = Scaler::Listener::BoshScaler::Condition::LastSampleConditionBase
        .new(processor, 'deployment0', 'job0', threshold)

      expect(condition).to receive(:sample).with(event01.to_hash).and_return(1)
      expect(condition).to receive(:sample).with(event03.to_hash).and_return(1)

      expect(threshold[:proc]).to receive(:call).with(1)

      condition.match
    end
  end
end

describe Scaler::Listener::BoshScaler::Condition::CfVarzAverageCondition do
  describe '#match' do
    it 'choose correct buffers to sample' do
      now = Time.now

      event00 = Scaler::CfVarzMetric.new(
        'deployment' => 'deployment0', 'job' => 'varz_job0', 'index' => 0,
        'key' => 'varz_key0', 'value' => 1, 'timestamp' => (now - 9).to_i
      )
      event01 = Scaler::CfVarzMetric.new(
        'deployment' => 'deployment0', 'job' => 'varz_job0', 'index' => 0,
        'key' => 'varz_key0', 'value' => 1, 'timestamp' => now.to_i
      )
      event02 = Scaler::CfVarzMetric.new(
        'deployment' => 'deployment0', 'job' => 'varz_job0', 'index' => 1,
        'key' => 'varz_key0', 'value' => 1, 'timestamp' => (now - 40).to_i
      )
      event03 = Scaler::CfVarzMetric.new(
        'deployment' => 'deployment0', 'job' => 'varz_job0', 'index' => 1,
        'key' => 'varz_key0', 'value' => 1, 'timestamp' => now.to_i
      )

      processor = Scaler::Listener::BoshScaler::CfVarzProcessor.new(1000)
      processor.process(event00)
      processor.process(event01)
      processor.process(event02)
      processor.process(event03)

      # metrics to be skipped
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'deployment' => 'deployment0', 'job' => 'varz_job1', 'index' => 0,
          'key' => 'varz_key0', 'timestamp' => (now - 59).to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'deployment' => 'deployment1', 'job' => 'varz_job0', 'index' => 1,
          'key' => 'varz_key0', 'timestamp' => now.to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'deployment' => 'deployment0', 'job' => 'varz_job1', 'index' => 2,
          'key' => 'varz_key0', 'timestamp' => now.to_i
        )
      )
      processor.process(
        Bosh::Monitor::Events::Heartbeat.new(
          'deployment' => 'deployment0', 'job' => 'varz_job0', 'index' => 3,
          'key' => 'varz_key1', 'timestamp' => now.to_i
        )
      )

      threshold = { :proc => instance_double(Proc) }
      condition = Scaler::Listener::BoshScaler::Condition::CfVarzAverageCondition
        .new(processor, 'deployment0', 'job0', threshold, 10, 'varz_job0', 'varz_key0')

      expect(condition).to receive(:sample).with(event01).and_call_original
      expect(condition).to receive(:sample).with(event00).and_call_original
      expect(condition).to receive(:sample).with(event03).and_call_original

      expect(threshold[:proc]).to receive(:call).with(1)

      condition.match
    end
  end
end
