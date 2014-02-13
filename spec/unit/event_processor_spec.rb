require 'spec_helper'

describe Scaler::EventProcessor do
  subject(:processor) { Scaler::EventProcessor.new(listeners) }

  describe '#process' do
    let(:listeners) { [listener0, listener1] }
    let(:listener0) { instance_double(Bosh::Monitor::Plugins::Base) }
    let(:listener1) { instance_double(Bosh::Monitor::Plugins::Base) }

    let(:event) { instance_double(Bosh::Monitor::Events::Base) }
    it 'redirects events to registered listeners' do
      expect(listener0).to receive(:process).with(event)
      expect(listener1).to receive(:process).with(event)
      processor.process(event)
    end
  end
end
