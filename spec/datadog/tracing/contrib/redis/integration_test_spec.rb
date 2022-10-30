require 'datadog/tracing/contrib/support/spec_helper'

require 'time'
require 'redis'
require 'ddtrace'

RSpec.describe 'Redis integration test' do
  before do
    skip unless ENV['TEST_DATADOG_INTEGRATION']

    use_real_tracer!

    Datadog.configure do |c|
      c.tracing.instrument :redis
    end
  end

  after do
    Datadog.registry[:redis].reset_configuration!
    without_warnings { Datadog.configuration.reset! }
  end
  let(:redis_options) { { host: host, port: port } }
  let(:redis) { Redis.new(redis_options.freeze) }
  let(:host) { ENV.fetch('T