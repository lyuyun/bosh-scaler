require 'spec_helper'

describe Scaler::Runner do
  include_context 'default values'

  let(:config_file_path) {
    File.join(assets_dir, 'config.yml')
  }

  describe '.run' do
    it 'starts runner' do
      expect_any_instance_of(Scaler::EventProcessor)
        .to receive(:run)

      expect_any_instance_of(Scaler::Listener::BoshScaler)
        .to receive(:run)

      expect_any_instance_of(Scaler::Collector::BoshNatsCollector)
        .to receive(:run)

      expect_any_instance_of(Scaler::Collector::CfVarzCollector)
        .to receive(:run)

      expect(EM).to receive(:run).and_yield

      Scaler::Runner.run(config_file_path)
    end
  end
end
