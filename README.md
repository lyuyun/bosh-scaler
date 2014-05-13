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


Basic Configuration
===================

See `config/sample.yml` for the basic configuration.


Defining Scaling Rules
======================

You can define scaling rules in your deployment manifests.

```yaml
---
deployment: cf

jobs:
  - name: router
    instances: 1
    resource_pool: medium_z1
    templates:
      - gorouter
  - name: runner
    instances: 3
    resource_pool: large_z1
    templates:
      - dea_next
      - dea_logging_agent

...snip...

scale:
  jobs:
    - name: router                            # Job name to scale
      cooldown: 300                           # seconds
      out:                                    # Scaling-out
        limit: 10                             # maximum instances
        unit: 2                               # Adds 2 instances at every event (default: 1)
        conditions:                           # Joined with OR for scaling-out
          - class: CpuAverage                 # CPU usage average
            larger_than: 80                   # Threshold (percent)
            duration: 300                     # For calculating average
          - class: MemoryAverage              # Memory usage average
            larger_than: 90                   # Threshold (percent)
            duration: 300                     # For calculating average
      in:                                     # Scaling-in
        limit: 3                              # minimum instances
        conditions:                           # Joined with AND for scaling-in
          - class: CpuAverage                 # CPU usage average
            smaller_than: 10                  # percent
            duration: 300                     # For calculating average
          - class: MemoryAverage              # Memory usage average
            smaller_than: 20                  # Threshold (percent)
            duration: 300                     # For calculating average
    - name: runner
      cooldown: 300
      out:
        limit: 20
        conditions:
          - class: CfVarzAverage              # Cloud Foundry Metrics
            varz_job: DEA                     # varz job name
            varz_key: available_memory_ratio  # varz key name
            smaller_than: 10
            duration: 300
      in:
        limit: 3
        conditions:
          - class: CfVarzAverage
            varz_job: DEA
            varz_key: available_memory_ratio
            larger_than: 80
            duration: 300
```

### Available conditions classes

#### BOSH Heartbeat

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

#### CF VARZ metrics

* CfVarzAverage
  * Average CF Varz value during `duration`


CF Plugin
=========

BOSH AutoScaler supports input from Cloud Foundry Collector. To use the `CfVarzAverage` condtion in your manifest file, send metrics to yoru AutoScaler with the TSDB historian.

### Sample Collector configuration with cf-release

```yaml
properties:
  collector:
    use_tsdb: true
    deployment_name: cf
  opentsdb:
    address: 192.168.15.139     # your AutoScaler address
    port: 4567                  # your AutoScaler port
```


Contributing
============

Fork the repository and send a new Pull Request with your topic branch.
