require 'datadog/tracing/contrib/integration_examples'
require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/analytics_examples'
require 'datadog/tracing/contrib/environment_service_name_examples'

require 'faraday'

require 'datadog/tracing'
require 'datadog/tracing/metadata/ext'

RSpec.describe 'Faraday middleware' do
  let(:client) do
    ::Faraday.new('http://example.com') do |builder|
      builder.use(:ddtrace, middleware_options) if use_middleware
      builder.adapter(:test) do |stub|
        stub.get('/success') { |_| [200, {}, 'OK'] }
        stub.post('/failure') { |_| [500, {}, 'Boom!'] }
        stub.get('/not_found') { |_| [404, {}, 'Not Found.'] }
        stub.get('/error') { |_| raise ::Faraday::ConnectionFailed, 'Test error' }
      end
    end
  end

  let(:use_middleware) { true }
  let(:middleware_options) { {} }
  let(:configuration_options) { {} }

  before do
    Datadog.configure do |c|
      c.tracing.instrument :faraday, configuration_options
    end
  end

  around do |example|
    # Reset before and after each example; don't allow global state to linger.
    Datadog.registry[:faraday].reset_configuration!
    example.run
    Datadog.registry[:faraday].reset_configuration!
  end

  context 'without explicit middleware configured' do
    subject(:response) { client.get('/success') }

    let(:use_middleware) { false }

    it_behaves_like 'environment service name', 'DD_TRACE_FARADAY_SERVICE_NAME'

    it 'uses default configuration' do
      expect(response.status).to eq(200)

      expect(span).to_not be nil
      expect(span.service).to eq(Datadog::Tracing::Contrib::Faraday::Ext::DEFAULT_PEER_SERVICE_NAME)
      expect(span.name).to eq(Datadog::T