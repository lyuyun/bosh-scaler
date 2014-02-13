require 'spec_helper'
require 'rack/test'

describe Scaler::Collector::CfVarzCollector do
  include_context 'default values'

  subject(:collector) {
    Scaler::Collector::CfVarzCollector.load(
      processor,
      logger,
      { 'port' => 3939 }
    )
  }

  let(:processor) {
    instance_double(Scaler::EventProcessor, :process => nil)
  }

  describe '#run' do
    it 'setup a sinatra server' do
      expect(Thin::Server)
        .to receive(:new)
        .with('0.0.0.0', 3939)
        .and_call_original
      expect_any_instance_of(Thin::Server)
        .to receive(:start!)

      collector.run
    end
  end

  describe Scaler::Collector::CfVarzCollector::ApiController do
    include Rack::Test::Methods

    def app
      Scaler::Collector::CfVarzCollector::ApiController
        .new(nil, processor, logger)
    end

    it 'sends event to the event processor' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)

      attribute_origin = {
        'deployment' => 'koala',
        'job' => 'crown',
        'index' => 39,
        'key' => 'koala.varz.key',
        'value' => 3939
      }

      event = Scaler::CfVarzMetric.new(
        attribute_origin.merge(
          'src' => 'koala.metric',
          'timestamp' => now.to_i
        )
      )
      expect(Scaler::CfVarzMetric).to receive(:new).and_return(event)
      expect(processor).to receive(:process).with(event)

      put('/metrics/koala.metric/values', Yajl::Encoder.encode(attribute_origin))
      expect(last_response).to be_ok
    end
  end

end
