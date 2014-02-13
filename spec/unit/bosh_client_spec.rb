require 'spec_helper'

describe Scaler::BoshClient do
  include_context 'default values'

  subject(:client) do
    Scaler::BoshClient.load(bosh_rest_options)
  end

  describe '#fetch_deployment_manifest' do
    it 'fetch a deployment manifest from the director' do
      stub_request(
        :get,
        'https://admin:admin@bosh.example.com:25555/deployments/test'
      ).to_return(:body => { 'manifest' => base_manifest }.to_json)

      expect(client.fetch_deployment_manifest('test')).to eq(base_manifest)
    end
  end

  describe '#deploy' do
    let(:response) {
      {
        :status => 302,
        :headers => { 'Location' => 'https://bosh.example.com/tasks/39' }
      }
    }

    it 'deploys a given manifest' do
      stub_request(
        :post,
        'https://admin:admin@bosh.example.com:25555/deployments'
      ).with(:body => base_manifest).to_return(response)

      expect(client.deploy(base_manifest).id).to eq('39')
    end
  end

  describe '#processing_deployment?' do
    let(:response) {
      {
        :status => 200,
        :body => [
          { 'description' => 'dummy' }
        ].to_json
      }
    }

    context 'a deployment task is being processed' do
      it 'returns true' do
        response[:body] = [
          { 'description' => 'dummy' },
          { 'description' => 'create deployment' }
        ].to_json

        stub_request(
          :get,
          'https://admin:admin@bosh.example.com:25555/tasks?state=processing'
        ).to_return(response)

        expect(client.processing_deployment?).to be true
      end
    end

    context 'no deployment task is being processed' do
      it 'returns false ' do
        stub_request(
          :get,
          'https://admin:admin@bosh.example.com:25555/tasks?state=processing'
        ).to_return(response)

        expect(client.processing_deployment?).to be false
      end
    end
  end

  describe '#fetch_vitals' do
    let(:response) {
      {
        :status => 302,
        :headers => { 'Location' => 'https://bosh.example.com/tasks/39' }
      }
    }

    it 'returns a task object for VMS' do
      stub_request(
        :get,
        'https://admin:admin@bosh.example.com:25555/deployments/koala/vms?format=full'
      ).to_return(response)

      expect(client.fetch_vitals('koala').id).to eq('39')
    end
  end

  describe '#fetch_deployments' do
    let(:response) {
      {
        :status => 200,
        :body => '[{"name":"koala","releases":[{"name":"koala","version":"39"}],"stemcells":[{"name":"koalastack","version":"3939"}]}]'
      }
    }

    it 'returns a task object for VMS' do
      stub_request(
        :get,
        'https://admin:admin@bosh.example.com:25555/deployments'
      ).to_return(response)

      expect(client.fetch_deployments[0]['name']).to eq('koala')
    end
  end

  describe '#fetch_agents' do
    let(:response) {
      {
        :status => 200,
        :body => '[{"agent_id":"koala0-aid","cid":"koala0-cid","job": "koala","index": 0}]'
      }
    }

    it 'returns agent information' do
      stub_request(
        :get,
        'https://admin:admin@bosh.example.com:25555/deployments/koala/vms'
      ).to_return(response)

      expect(client.fetch_agents('koala')[0]['agent_id']).to eq('koala0-aid')
    end
  end

  describe '#fetch_task_state' do
    let(:response) {
      {
        :status => 200,
        :body => { 'id' => 39, 'state' => 'error' }.to_json
      }
    }

    it 'returns task state' do
      stub_request(
        :get,
        'https://admin:admin@bosh.example.com:25555/tasks/39'
      ).to_return(response)

      expect(client.fetch_task_state(39)).to eq('error')
    end
  end

  describe '#fetch_task_result' do
    let(:response) {
      {
        :status => 200,
        :body => Array.new(3, '{"favorite":"koala"}').join("\n")
      }
    }

    it 'returns task state' do
      stub_request(
        :get,
        'https://admin:admin@bosh.example.com:25555/tasks/39/output?type=result'
      ).to_return(response)

      result = client.fetch_task_result(39)
      expect(result).to eq(Array.new(3, '{"favorite":"koala"}').join("\n"))
    end
  end
end
