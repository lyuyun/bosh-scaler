require 'spec_helper'

describe Scaler::Collector::BoshNatsCollector do
  include_context 'default values'

  subject(:collector) {
    Scaler::Collector::BoshNatsCollector.load(
      processor,
      logger,
      {
        'bosh_nats' => bosh_nats_options,
        'bosh_rest' => bosh_rest_options
      }
    )
  }

  let(:processor) {
    instance_double(Scaler::EventProcessor, :process => nil)
  }

  let(:nats) {
    instance_double(NATS, :on_error => nil)
  }

  describe '#run' do
    it 'sets up a NATS client' do
      expect(nats)
        .to receive(:subscribe)
        .with('hm.agent.heartbeat.*')

      expect(NATS)
        .to receive(:connect)
        .with(
          :uri => 'mbus://nats.example.com:4222',
          :user => 'nats',
          :pass => 'nats',
          :autostart => false
        )
        .and_return(nats)

      expect(collector).to receive(:sync_deployments)
      collector.run
    end
  end

  describe '#sync_deployments' do
    it 'loads existing deployments and agents information' do
      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployments)
        .and_return([{ 'name' => 'koala' }, { 'name' => 'crown' }])
      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_agents)
        .with('koala')
        .and_return([{ 'agent_id' => 'koala-agent' }])
      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_agents)
        .with('crown')
        .and_return([{ 'agent_id' => 'crown-agent' }])

      collector.sync_deployments
      expect(collector.instance_variable_get('@deployments'))
        .to eq('koala-agent' => 'koala', 'crown-agent' => 'crown')
    end
  end

  describe '#handle_heartbeat' do
    it '' do
      event = instance_double(Bosh::Monitor::Events::Heartbeat)
      expect(Bosh::Monitor::Events::Heartbeat)
        .to receive(:new)
        .and_return(event)
      expect(processor)
        .to receive(:process)
        .with(event)

      expect(collector)
        .to receive(:sync_deployments)

      collector
        .handle_heartbeat(
          '{"job":"koala","index":0,"job_state":"running","vitals":{"load":["0.00","0.01","0.05"],"cpu":{"user":"0.0","sys":"0.0","wait":"0.0"},"mem":{"percent":"20.7","kb":"425948"},"swap":{"percent":"0.0","kb":"0"},"disk":{"system":{"percent":"7","inode_percent":"4"}}},"ntp":{"message":"file missing"}}',
          'hm.agent.heartbeat.koala')
    end
  end
end
