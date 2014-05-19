require 'spec_helper'

describe Scaler::Listener::BoshScaler do
  include_context 'default values'

  let(:scaler_manifest0_before) {
    File.read(File.join(assets_dir, 'scaler_manifest0_before.yml'))
  }
  let(:scaler_manifest1_before) {
    File.read(File.join(assets_dir, 'scaler_manifest1_before.yml'))
  }
  let(:scaler_manifest2_before) {
    File.read(File.join(assets_dir, 'scaler_manifest2_before.yml'))
  }
  let(:scaler_manifest0_after) {
    File.read(File.join(assets_dir, 'scaler_manifest0_after.yml'))
  }
  let(:scaler_manifest1_after) {
    File.read(File.join(assets_dir, 'scaler_manifest1_after.yml'))
  }
  let(:scaler_manifest2_after) {
    File.read(File.join(assets_dir, 'scaler_manifest2_after.yml'))
  }

  subject(:scaler) {
    Scaler::Listener::BoshScaler.new(
        'buffer_size' => 1000,
        'interval' => 60,
        'bosh_rest' => bosh_rest_options
      )
  }

  before(:each) {
    Bhm.logger = logger
  }

  describe '#initialize' do
    it 'sets BOSH @user name' do
      expect(scaler.user).to eq('admin')
    end

    context 'when UI is enabled' do
      subject(:scaler) {
        Scaler::Listener::BoshScaler.new(
          'buffer_size' => 1000,
          'interval' => 60,
          'bosh_rest' => bosh_rest_options,
          'ui' => { 'enable' => true, 'port' => '3939' }
        )
      }

      it 'sets insatnce variables' do
        expect(scaler.instance_variable_get('@ui_enabled')).to eq(true)
        expect(scaler.instance_variable_get('@ui_port')).to eq('3939')
      end

      context 'when port number not given' do
        it 'raises an error' do
          expect {
            Scaler::Listener::BoshScaler.new(
              'buffer_size' => 1000,
              'interval' => 60,
              'bosh_rest' => bosh_rest_options,
              'ui' => { 'enable' => true }
            )
          }.to raise_error('Port number for UI is not given')
        end
      end
    end
  end

  describe '#update_rules' do
    def expect_rule_defined(
        rules,
        deployment_name, job_name,
        cooldown_time, out_limit, in_limit, out_unit, in_unit,
        out_condition_classes, in_condition_classes)
      expect(rules).to have_key(deployment_name)
      expect(rules[deployment_name]).to have_key(job_name)
      job = rules[deployment_name][job_name]
      expect(job[:cooldown_time]).to eq(cooldown_time)
      expect(job[:out_limit]).to eq(out_limit)
      expect(job[:in_limit]).to eq(in_limit)
      expect(job[:out_unit]).to eq(out_unit || 1)
      expect(job[:in_unit]).to eq(in_unit || 1)
      expect_list_matches(job[:out_conditions], out_condition_classes)
      expect_list_matches(job[:in_conditions], in_condition_classes)
    end

    def expect_list_matches(instances, klasses)
      checkees = instances.dup
      klasses.each do |klass|
        found = checkees.delete_if { |checkee| checkee.class == klass }
        expect(found).not_to be_nil
      end
      expect(checkees).to be_empty
    end

    it 'sets up rules' do
      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployments)
        .and_return([{ 'name' => 'test0' }, { 'name' => 'test1' }])

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('test0')
        .and_return(scaler_manifest0_before)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('test1')
        .and_return(scaler_manifest1_before)

      scaler.update_rules
      rules = scaler.instance_variable_get('@rules')

      expect_rule_defined(
        rules, 'test0', 'go1o', 39, 8, 2, 3, 4,
        [Scaler::Listener::BoshScaler::Condition::MemoryAverageCondition],
        [Scaler::Listener::BoshScaler::Condition::CpuAverageCondition]
      )
      expect_rule_defined(
        rules, 'test0', 'go1i', 702, nil, 2, 1, 1,
        [],
        [Scaler::Listener::BoshScaler::Condition::MemoryAverageCondition]
      )
      expect_rule_defined(
        rules, 'test1', 'go0o', 39, 39, 7, 1, 1,
        [
          Scaler::Listener::BoshScaler::Condition::CpuAverageCondition,
          Scaler::Listener::BoshScaler::Condition::MemoryAverageCondition
        ],
        [Scaler::Listener::BoshScaler::Condition::CpuAverageCondition]
      )
      expect_rule_defined(
        rules, 'test1', 'go0i', 702, 101, nil, 1, 1,
        [Scaler::Listener::BoshScaler::Condition::MemoryAverageCondition],
        []
      )
    end

    it 'keeps :last_fired_time of existing rules' do
      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployments)
        .twice
        .and_return([{ 'name' => 'test2' }])

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('test2')
        .and_return(scaler_manifest2_before)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('test2')
        .and_return(scaler_manifest2_after)

      step1 = Time.now
      allow(Time).to receive(:now).and_return(step1)
      scaler.update_rules
      rules = scaler.instance_variable_get('@rules')
      expect(rules['test2']['job0'][:last_fired_time])
        .to eq(nil)
      rules['test2']['job0'][:last_fired_time] = step1 # inject

      step2 = step1 + 1000
      allow(Time).to receive(:now).and_return(step2)
      scaler.update_rules
      rules = scaler.instance_variable_get('@rules')
      expect(rules['test2']['job0'][:last_fired_time])
        .to eq(step1)
      expect(rules['test2']['job1'][:last_fired_time])
        .to eq(nil)
    end
  end

  describe '#run' do
    it 'sets up event handlers' do
      allow(EM).to receive(:reactor_running?).and_return(true)

      expect(scaler).to receive(:update_rules)
      expect(EM)
        .to receive(:add_periodic_timer)
        .with(60)
        .and_yield
      expect(scaler).to receive(:update_rules)

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

    context 'when the UI is enabled' do
      subject(:scaler) {
        Scaler::Listener::BoshScaler.new(
          'buffer_size' => 1000,
          'interval' => 60,
          'bosh_rest' => bosh_rest_options,
          'ui' => { 'enable' => true, 'port' => '3939' }
        )
      }

      it 'sets up UI' do
        allow(EM).to receive(:reactor_running?).and_return(true)
        allow(scaler).to receive(:update_rules)
        allow(EM).to receive(:add_periodic_timer)
        ui = instance_double(Scaler::Listener::BoshScaler::Ui, :run => nil)
        expect(Scaler::Listener::BoshScaler::Ui)
          .to receive(:new)
          .with(scaler, '3939', logger)
          .and_return(ui)
        scaler.run
      end
    end
  end

  describe '#try_rules' do

    let(:rules) {
      {
        'test0' => {
          :out => [
            { :name => 'go0o', :out_limit => 1000, :out_unit => 3 },
            { :name => 'stop0o', :out_limit => 1000, :out_unit => 1 }
          ],
          :in => [
            { :name => 'go0i', :in_limit => 1000 , :in_unit => 5 },
            { :name => 'stop0i', :in_limit => 1000, :in_unit => 1 }
          ]
        },
        'test1' => {
          :out => [
            { :name => 'go1o', :out_limit => 1000, :out_unit => 1 },
            { :name => 'stop1o', :out_limit => 1000, :out_unit => 1 }
          ],
          :in => [
            { :name => 'go1i', :in_limit => 1000, :in_unit => 1 },
            { :name => 'stop1i', :in_limit => 1000, :in_unit => 1 }
          ]
        }
      }
    }

    before(:each) {
      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployments)
        .and_return([{ 'name' => 'test0' }, { 'name' => 'test1' }])

      allow_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('test0')
        .and_return(scaler_manifest0_before)

      allow_any_instance_of(Scaler::BoshClient)
        .to receive(:fetch_deployment_manifest)
        .with('test1')
        .and_return(scaler_manifest1_before)
      scaler.update_rules
    }

    it 'scale deploymentes' do
      expect(scaler)
        .to receive(:search_jobs_to_scale)
        .and_return(rules)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:processing_deployment?)
        .twice
        .and_return(false)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:deploy)
        .with(Scaler::Deployment.load_yaml(scaler_manifest0_after).to_yaml)

      expect_any_instance_of(Scaler::BoshClient)
        .to receive(:deploy)
        .with(Scaler::Deployment.load_yaml(scaler_manifest1_after).to_yaml)

      now = Time.now
      allow(Time).to receive(:now).and_return(now)

      scaler.try_rules

      rules.each do |_, direction|
        direction.each do |_, jobs|
          jobs.each do |job|
            next unless job[:name].match(/^go/)
            expect(job[:last_fired_time]).to eq(now)
          end
        end
      end
    end

    context 'another deployment is under processing' do
      it 'skips scaling' do
        expect(scaler)
          .to receive(:search_jobs_to_scale)
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

  describe '#search_jobs_to_scale' do
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
      rules = {
        'deployment0' => {
          'out0' => {
            :name => 'out0',
            :out_conditions => [true_condition, false_condition],
            :in_conditions => [false_condition]
          },
          'in0' => {
            :name => 'in0',
            :out_conditions => [false_condition],
            :in_conditions => [true_condition]
          },
          'not_match' => {
            :name => 'not_match',
            :out_conditions => [false_condition],
            :in_conditions => [false_condition, true_condition]
          },
          'out1' => {
            :name => 'out1',
            :out_conditions => [true_condition, true_condition],
            :in_conditions => [true_condition]
          }
        },
        'deployment1' => {
          'in1' => {
            :name => 'in1',
            :out_conditions => [false_condition],
            :in_conditions => [true_condition, true_condition]
          }
        }
      }
      rules.each do |_, jobs|
        jobs.each do |_, job|
          job[:last_fired_time] = Time.at(0)
          job[:cooldown_time] = 0
        end
      end

      scaler.instance_variable_set('@rules', rules)
      expect(scaler.search_jobs_to_scale)
        .to eq({
          'deployment0' => {
            :out => [
              rules['deployment0']['out0'],
              rules['deployment0']['out1']
            ],
            :in => [
              rules['deployment0']['in0']
            ]
          },
          'deployment1' => {
            :out => [],
            :in => [
              rules['deployment1']['in1']
            ]
          }
        })
    end

    it 'drops rules in its cooldown time' do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      rules = {
        'deployment0' => {
          'out0' => {
            :name => 'out0',
            :last_fired_time => now + 9999,
            :cooldown_time => 0,
            :out_conditions => [true_condition],
            :in_conditions => [false_condition]
          }
        }
      }
      scaler.instance_variable_set('@rules', rules)
      expect(scaler.search_jobs_to_scale)
        .to eq({ 'deployment0' => { :out => [], :in => [] } })
    end
  end
end
