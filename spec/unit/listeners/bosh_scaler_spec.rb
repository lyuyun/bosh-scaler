require 'spec_helper'

describe Scaler::Listener::BoshScaler do
  include_context 'default values'

  subject(:scaler) {
    Scaler::Listener::BoshScaler.new(

        'buffer_size' => 1000,
        'interval' => 60,
        'bosh_rest' => bosh_rest_options,
        'rules' => [
          {
            'deployment' => 'koala',
            'job' => 'crown',
            'cooldown' => 100,
            'out' => {
              'limit' => 3939,
              'condition' => {
                'class' => 'CpuAverage',
                'larger_than' => 90,
                'duration' => 300
              }
            },
            'in' => {
              'limit' => 39,
              'condition' => {
                'class' => 'MemoryAverage',
                'smaller_than' => 10,
                'duration' => 300
              }
            }
          }
        ]
      )
  }

  describe '#initialize' do
    it 'sets up rules' do
      rule = scaler.instance_variable_get('@rules')[0]
      expect(rule['deployment']).to eq('koala')
      expect(rule['job']).to eq('crown')
      expect(rule['cooldown']).to eq(100)
      out_condition = rule['out']['condition']
      expect(out_condition.is_a?(Scaler::Listener::BoshScaler::Condition::CpuAverageCondition))
        .to be true
      in_condition = rule['in']['condition']
      expect(in_condition.is_a?(Scaler::Listener::BoshScaler::Condition::MemoryAverageCondition))
        .to be true
    end
  end

  describe '#run' do
    it 'sets up event handlers' do
      Bhm.logger = logger
      allow(EM).to receive(:reactor_running?).and_return(true)

      expect(EM)
        .to receive(:add_periodic_timer)
        .with(60)
        .and_yield
      expect(scaler).to receive(:try_rules)

      expect(EM)
        .to receive(:add_periodic_timer)
        .with(60 * 60 * 24)
        .and_yield
      expect_any_instance_of(Scaler::Listener::BoshScaler::HeartbeatProcessor)
        .to receive(:drop_missing_entities)
      expect_any_instance_of(Scaler::Listener::BoshScaler::CfVarzProcessor)
        .to receive(:drop_missing_entities)

      scaler.run
    end
  end

  describe '#try_rules' do
    let(:scaler_manifest) {
      File.read(File.join(assets_dir, 'scaler_manifest.yml'))
    }

    let(:scaler_manifest0) {
      File.read(File.join(assets_dir, 'scaler_manifest0.yml'))
    }

    let(:scaler_manifest1) {
      File.read(File.join(assets_dir, 'scaler_manifest1.yml'))
    }

    let(:rules) {
      {
        'deployment0' => {
          :out => [
            { 'job' => 'go0o', 'out' => { 'limit' => 1000 } },
            { 'job' => 'stop0o', 'out' => { 'limit' => 1000 } }
          ],
          :in => [
            { 'job' => 'go0i', 'in' => { 'limit' => 1000 } },
            { 'job' => 'stop0i', 'in' => { 'limit' => 1000 } }
          ]
        },
        'deployment1' => {
          :out => [
            { 'job' => 'go1o', 'out' => { 'limit' => 1000 } },
            { 'job' => 'stop1o', 'out' => { 'limit' => 1000 } }
          ],
          :in => [
            { 'job' => 'go1i', 'in' => { 'limit' => 1000 } },
            { 'job' => 'stop1i', 'in' => { 'limit' => 1000 } }
          ]
        }
      }
    }

    before(:each) {
      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('deployment0')
        .and_return(scaler_manifest)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('deployment1')
        .and_return(scaler_manifest)
    }

    it 'scale deploymentes' do
      expect(scaler)
        .to receive(:extract_condition_matched_rules)
        .and_return(rules)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:processing_deployment?)
        .twice
        .and_return(false)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:deploy)
        .with(Scaler::Deployment.load_yaml(scaler_manifest0).to_yaml)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:deploy)
        .with(Scaler::Deployment.load_yaml(scaler_manifest1).to_yaml)

      scaler.try_rules
    end

    context 'another deployment is under processing' do
      it 'skips scaling' do
        expect(scaler)
          .to receive(:extract_condition_matched_rules)
          .and_return(rules)

        expect_any_instance_of(Scaler::BoshClient)
          .to receive(:processing_deployment?)
          .twice
          .and_return(true)

        expect_any_instance_of(Scaler::BoshClient)
          .not_to receive(:deploy)

        scaler.try_rules
      end
    end
  end

  describe '#extract_condition_matched_rules' do

    let(:true_condition) {
      instance_double(
        Scaler::Listener::BoshScaler::Condition::Base,
        :match => true)
    }

    let(:false_condition) {
      instance_double(
        Scaler::Listener::BoshScaler::Condition::Base,
        :match => false)
    }

    it 'extracts only matched rules' do
      rules = [
        {
          'deployment' => 'deployment0',
          'job' => 'out0',
          'out' => { 'condition' => true_condition },
          'in' => { 'condition' => false_condition }
        },
        {
          'deployment' => 'deployment0',
          'job' => 'in0',
          'out' => { 'condition' => false_condition },
          'in' => { 'condition' => true_condition }
        },
        {
          'deployment' => 'deployment0',
          'job' => 'not_match',
          'out' => { 'condition' => false_condition },
          'in' => { 'condition' => false_condition }
        },
        {
          'deployment' => 'deployment0',
          'job' => 'out1',
          'out' => { 'condition' => true_condition },
          'in' => { 'condition' => true_condition }
        },
        {
          'deployment' => 'deployment1',
          'job' => 'in1',
          'out' => { 'condition' => false_condition },
          'in' => { 'condition' => true_condition }
        }
      ]
      rules.each do |rule|
        rule['last_fired_time'] = Time.at(0)
        rule['cooldown'] = 0
      end

      scaler.instance_variable_set('@rules', rules)
      expect(scaler.extract_condition_matched_rules)
        .to eq(

          'deployment0' => {
            :out => [rules[0], rules[3]], :in => [rules[1]]
          },
          'deployment1' => {
            :out => [], :in => [rules[4]]
          }
        )
    end

    it 'drops rules in its cooldown time' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      rules = [
        {
          'deployment' => 'deployment0',
          'last_fired_time' => now + 9999,
          'cooldown' => 0,
          'job' => 'out0',
          'out' => { 'condition' => true_condition },
          'in' => { 'condition' => false_condition }
        }
      ]
      scaler.instance_variable_set('@rules', rules)
      expect(scaler.extract_condition_matched_rules)
        .to eq({})
    end
  end
end
