BOSH AutoScaler with CF Plugin
------------------------------

[![Build Status](https://travis-ci.org/nttlabs/bosh-scaler.png?branch=master)](https://travis-ci.org/nttlabs/bosh-scaler)
[![Code Climate](https://codeclimate.com/github/nttlabs/bosh-scaler.png)](https://codeclimate.com/github/nttlabs/bosh-scaler)


Requirements
============

* Ruby
* Bundler
* BOSH


Getting started
===============

```sh
# Clone the repository
git clone https://github.com/nttlabs/bosh_scaler.git
cd bosh_scaler

# Create a config file
vi ./config/sample.yml

# Install required gems
bundle install

# Run
bundle exec ./bin/scaler ./config/sample.yml
```


Configuration
=============

See `config/sample.yml` for the basic configuration.

### Available conditions classes

* CpuAverage
  * Average CPU percentage during `duration`
* MemoryAverage
  * Avarage memory percentage during `duration`
* LoadAverage1
  * Latest Load Average in 1 minute
* LoadAverage5
  * Latest Load Average in 5 minutes
* LoadAverage15
  * Latest Load Average in 15 minute
* CfVarzAverage
  * Average CF Varz value during `duration`


CF Plugin
=========

To utilize the `CfVarzAverage` class in rule conditions, `CfVarzCollector` must be activated. `CfVarzCollector` launches an HTTP server at a configured port and you can send Varz metrics to the server from your CF deployment using the Collector.

You need to configure your Collector to send metrics to your scaler. The `cf_metrics` historian is available for sending metrics to the scaler.

### Note

The `cf_metrics` historian has a hard-coded `https` scheme in the endpoint URL. You need to setup a SSL reverse-proxy server to translate `https` to `http` or [modify the endpoint URL](https://github.com/cloudfoundry/collector/blob/master/lib/collector/historian/cf_metrics.rb#L34). `CfVarzCollector` does not support the SSL at this moement.

### Sample Collector configuration

```yaml
index: 0

logging:
  level: debug
  file: /tmp/collector_test.log
  syslog: vcap.collector

mbus: nats://nats:c1oudc0cf.nats.host.name:4222

intervals:
  discover: 60
  varz: 10
  healthz: 5
  local_metrics: 10
  prune: 300
  nats_ping: 10

deployment_name: cf
cf_metrics:
  host: auto.scaler.ip.address:4567
```


Contributing
============

Fork the repository and send a new Pull Request with your topic branch.
