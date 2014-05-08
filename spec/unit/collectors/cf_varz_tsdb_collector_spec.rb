require 'spec_helper'

describe Scaler::Collector::CfVarzTsdbCollector do
  include_context 'default values'

  subject(:collector) {
    Scaler::Collector::CfVarzTsdbCollector.load(
      processor,
      logger,
      { 'port' => 3939 }
    )
  }

  let(:processor) {
    instance_double(Scaler::EventProcessor, :process => nil)
  }

  describe '#run' do
    it 'setup a TCP server at the given port' do
      expect(EventMachine)
        .to receive(:start_server)
        .with(
          '0.0.0.0',
          3939,
          Scaler::Collector::CfVarzTsdbCollector::TsdbServer,
          logger,
          collector
        )

      collector.run
    end
  end

  describe '#receive_line' do
    it 'sends event to the event processor' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)

      key = 'koala.varz.key'
      value = 3939

      tags = {
        'deployment' => 'koala',
        'job' => 'crown',
        'index' => 39
      }

      event = Scaler::CfVarzMetric.new(
        tags.merge(
          'key' => key,
          'value' => value,
          'src' => 'koala.metric',
          'timestamp' => now.to_i
        )
      )
      expect(Scaler::CfVarzMetric).to receive(:new).and_return(event)
      expect(processor).to receive(:process).with(event)

      tsdb_command =
        "put #{key} 3939 #{value}"
      tsdb_command += tags.map { |k, v| "#{k}=#{v}" }.join(' ')

      collector.receive_line(tsdb_command)
    end
  end

end
