require 'datadog/tracing/contrib/support/spec_helper'

require 'redis'
require 'ddtrace'

RSpec.describe 'Redis instrumentation test' do
  let(:test_host) { ENV.fetch('TEST_REDIS_HOST', '127.0.0.1') }
  let(:test_port) { ENV.fetch('TEST_REDIS_PORT', 6379).to_i }

  # Redis instance supports 16 databases,
  # the default is 0 but can be changed to any number from 0-15,
  # to configure support more databases, check `redis.conf`
  # since 0 is the default, the SELECT db command would be skipped
  let(:test_database) { 15 }

  around do |example|
    # Reset before and after each example; don't allow global state to linger.
    Datadog.registry[:redis].reset_configuration!
    example.run
    Datadog.registry[:redis].reset_configuration!
  end

  before do
    skip unless ENV['TEST_DATADOG_INTEGRATION']
  end

  RSpec::Matchers.define :be_a_redis_span do
    match(notify_expectation_failures: true) do |span|
      expect(span.name).to eq('redis.command')
      expect(span.span_type).to eq('redis')

      expect(span.resource).to eq(@resource)
      expect(span.service).to eq(@service)

      expect(span).to_not have_error
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('redis')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION)).to eq('command')

      expect(span.get_tag('out.host')).to eq(@host)
      expect(span.get_tag('out.port')).to eq(@port.to_f)
      expect(span.get_tag('redis.raw_command')).to eq(@raw_command)
      expect(span.get_tag('db.system')).to eq('redis')
      expect(span.get_tag('db.redis.database_index')).to eq(@db.to_s)
    end

    chain :with do |opts|
      @resource = opts.fetch(:resource)
      @service = opts.fetch(:service)
      @raw_command = opts.fetch(:raw_command)
      @host = opts.fetch(:host)
      @port = opts.fetch(:port)
      @db = opts.fetch(:db)
    end
  end

  describ