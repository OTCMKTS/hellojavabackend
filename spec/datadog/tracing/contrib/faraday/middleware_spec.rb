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
      expect(span.name).to eq(Datadog::Tracing::Contrib::Faraday::Ext::SPAN_REQUEST)
      expect(span.resource).to eq('GET')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_METHOD)).to eq('GET')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_STATUS_CODE)).to eq('200')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_URL)).to eq('/success')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::NET::TAG_TARGET_HOST)).to eq('example.com')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::NET::TAG_TARGET_PORT)).to eq(80)
      expect(span.span_type).to eq(Datadog::Tracing::Metadata::Ext::HTTP::TYPE_OUTBOUND)
      expect(span).to_not have_error

      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('faraday')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION)).to eq('request')
      expect(span.get_tag('span.kind')).to eq('client')
    end

    it_behaves_like 'a peer service span' do
      let(:peer_hostname) { 'example.com' }
    end

    it 'executes without warnings' do
      expect { response }.to_not output(/WARNING/).to_stderr
    end

    context 'with default Faraday connection' do
      subject(:response) { client.get('http://example.com/success') }

      let(:client) { ::Faraday } # Use the singleton client

      before do
        # We mock HTTP requests we we can't configure
        # the test adapter for the default connection
        WebMock.enable!
        stub_request(:get, /example.com/).to_return(status: 200)
      end

      after { WebMock.disable! }

      it_behaves_like 'environment service name', 'DD_TRACE_FARADAY_SERVICE_NAME'

      it 'uses default configuration' do
        expect(response.status).to eq(200)

        expect(span.service).to eq(Datadog::Tracing::Contrib::Faraday::Ext::DEFAULT_PEER_SERVICE_NAME)
        expect(span.name).to eq(Datadog::Tracing::Contrib::Faraday::Ext::SPAN_REQUEST)
        expect(span.resource).to eq('GET')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_METHOD)).to eq('GET')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_STATUS_CODE)).to eq('200')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_URL)).to eq('/success')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::NET::TAG_TARGET_HOST)).to eq('example.com')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::NET::TAG_TARGET_PORT)).to eq(80)
        expect(span.span_type).to eq(Datadog::Tracing::Metadata::Ext::HTTP::TYPE_OUTBOUND)
        expect(span).to_not have_error

        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('faraday')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION)).to eq('request')
        expect(span.get_tag('span.kind')).to eq('client')
      end

      it 'executes without warnings' do
        expect { response }.to_not output(/WARNING/).to_stderr
      end

      context 'with basic auth' do
        subject(:response) { client.get('http://username:password@example.com/success') }

        it 'does not collect auth info' do
          expect(response.status).to eq(200)

          expect(span.get_tag('http.url')).to eq('/success')
        end

        it 'executes without warnings' do
          expect { response }.to_not output(/WARNING/).to_stderr
        end
      end
    end
  end

  context 'when there is no interference' do
    subject!(:response) { client.get('/success') }

    it_behaves_like 'environment service name', 'DD_TRACE_FARADAY_SERVICE_NAME'

    it do
      expect(response).to be_a_kind_of(::Faraday::Response)
      expect(response.body).to eq('OK')
      expect(response.status).to eq(200)
    end
  end

  context 'when there is successful request' do
    subject!(:response) { client.get('/success') }

    it_behaves_like 'environment service name', 'DD_TRACE_FARADAY_SERVICE_NAME'

    it_behaves_like 'analytics for integration' do
      let(:analytics_enabled_var) { Datadog::Tracing::Contrib::Faraday::Ext::ENV_ANALYTICS_ENABLED }
      let(:analytics_sample_rate_var) { Datadog::Tracing::Contrib::Faraday::Ext::ENV_ANALYTICS_SAMPLE_RATE }
    end

    it_behaves_like 'measured span for integration', false

    it do
      expect(span).to_not be nil
      expect(span.service).to eq(Datadog::Tracing::Contrib::Faraday::Ext::DEFAULT_PEER_SERVICE_NAME)
      expect(span.name).to eq(Datadog::Tracing::Contrib::Faraday::Ext::SPA