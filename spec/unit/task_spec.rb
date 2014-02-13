require 'spec_helper'

describe Scaler::Task do
  include_context 'default values'

  let(:bosh_client) {
    double(Scaler::BoshClient, :fetch_task_state => 'processing')
  }

  subject(:task) {
    Scaler::Task.new(39, bosh_client)
  }

  describe '#update_state' do
    it 'returns a new state of a task' do
      expect(task.update_state).to eq('processing')
      expect(task.state).to eq('processing')

      allow(bosh_client).to receive(:fetch_task_state).and_return('done')

      expect(task.update_state).to eq('done')
      expect(task.state).to eq('done')
    end
  end

  describe '#result' do
    it 'returns the result of a task' do
      expect(bosh_client).to receive(:fetch_task_result).and_return('result')
      expect(task.result).to eq('result')
      expect(task.result).to eq('result') # cached value
    end
  end
end
