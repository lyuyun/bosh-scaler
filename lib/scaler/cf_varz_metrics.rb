class Scaler::CfVarzMetric < Bosh::Monitor::Events::Base
  attr_reader :deployment
  attr_reader :job
  attr_reader :index
  attr_reader :timestamp
  attr_reader :key
  attr_reader :value

  def initialize(attributes = {})
    super
    @kind = :cf_collector_metric

    @deployment = attributes['deployment']
    @job = attributes['job']
    @index = attributes['index']
    @key = attributes['key']
    @value = attributes['value']

    begin
      @timestamp = Time.at(@attributes['timestamp'])
    rescue
      @attributes['timestamp']
    end
  end

  def source_id
    "#{@deployment}/#{@job}/#{@index}"
  end

  def validate
    add_error('deployment is missing') if @deployment.nil?
    add_error('job is missing') if @job.nil?
    add_error('index is missing') if @index.nil?
    add_error('key is missing') if @key.nil?
    add_error('timestamp is missing') if @timestamp.nil?
  end
end
