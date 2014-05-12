require 'rspec'
require 'scaler'
require 'webmock/rspec'
require 'logger'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end

shared_context 'default values' do
  let(:assets_dir) { File.join('.', 'spec', 'assets') }
  let(:base_manifest) {
    File.read(File.join(assets_dir, 'base_manifest.yml'))
  }
  let(:updated_manifest) {
    File.read(File.join(assets_dir, 'updated_manifest.yml'))
  }

  let(:logger) { Logger.new('/dev/null') }

  let(:bosh_nats_options) {
    {
      'uri' => 'mbus://nats.example.com:4222',
      'user' => 'nats',
      'pass' => 'nats'
    }
  }

  let(:bosh_rest_options) {
    {
      'endpoint_uri' => 'https://bosh.example.com:25555',
      'user' => 'admin',
      'password' => 'admin',
      'disable_verify_certification' => true
    }
  }
end
