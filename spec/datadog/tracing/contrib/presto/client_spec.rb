
require 'datadog/tracing/contrib/integration_examples'
require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/analytics_examples'
require 'datadog/tracing/contrib/environment_service_name_examples'

require 'ddtrace'
require 'presto-client'

RSpec.describe 'Presto::Client instrumentation' do
  let(:configuration_options) { {} }

  let(:client) do
    Presto::Client.new(
      server: "#{host}:#{port}",
      user: user,
      schema: schema,
      catalog: catalog,
      time_zone: time_zone,
      language: language,
      http_proxy: http_proxy,
      model_version: model_version
    )
  end
  let(:service) { 'presto' }
  let(:host) { ENV.fetch('TEST_PRESTO_HOST', 'localhost') }
  let(:port) { ENV.fetch('TEST_PRESTO_PORT', 8080).to_i }
  let(:user) { 'test_user' }
  let(:schema) { 'test_schema' }
  let(:catalog) { 'memory' }
  let(:time_zone) { 'US/Pacific' }
  let(:language) { 'English' }
  let(:http_proxy) { 'proxy.example.com:8080' }
  let(:model_version) { '0.205' }

  let(:presto_client_gem_version) { Gem.loaded_specs['presto-client'].version }

  # Using a global here so that after presto is online we don't keep repeating this check for other tests
  # rubocop:disable Style/GlobalVars
  before do
    unless $presto_is_online
      try_wait_until(seconds: 10) { presto_online? }
      $presto_is_online = true
    end
  end

  def presto_online?
    client.run('SELECT 1')
    true
  rescue Presto::Client::PrestoQueryError => e
    if e.message.include?('Presto server is still initializing')
      puts 'Presto not online yet'
      false
    else
      raise
    end
  end

  before do
    Datadog.configure do |c|
      c.tracing.instrument :presto, configuration_options
    end
  end

  around do |example|
    without_warnings do
      Datadog.registry[:presto].reset_configuration!
      example.run
      Datadog.registry[:presto].reset_configuration!
      Datadog.configuration.reset!
    end
  end

  context 'when the tracer is disabled' do
    before do
      Datadog.configure do |c|
        c.tracing.enabled = false
      end
    end

    after { Datadog.configuration.tracing.reset! }

    it 'does not produce spans' do
      client.run('SELECT 1')
      expect(spans).to be_empty
    end
  end

  describe 'tracing' do
    shared_examples_for 'a Presto trace' do
      it 'has basic properties' do
        expect(spans).to have(1).items
        expect(span.service).to eq(service)
        expect(span.get_tag('presto.schema')).to eq(schema)
        expect(span.get_tag('presto.catalog')).to eq(catalog)
        expect(span.get_tag('presto.user')).to eq(user)
        expect(span.get_tag('presto.time_zone')).to eq(time_zone)
        expect(span.get_tag('presto.language')).to eq(language)
        expect(span.get_tag('presto.http_proxy')).to eq(http_proxy)
        expect(span.get_tag('presto.model_version')).to eq(model_version)
        expect(span.get_tag('out.host')).to eq(host)
        expect(span.get_tag('out.port')).to eq(port)
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('presto')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION)).to eq(operation)
        expect(span.get_tag('span.kind')).to eq('client')
        expect(span.get_tag('db.system')).to eq('presto')
      end
    end

    shared_examples_for 'a configurable Presto trace' do
      context 'when the client is configured' do
        it_behaves_like 'environment service name', 'DD_TRACE_PRESTO_SERVICE_NAME'

        context 'with a different service name' do
          let(:service) { 'presto-primary' }
          let(:configuration_options) { { service_name: service } }

          it_behaves_like 'a Presto trace'
        end

        context 'with a different schema' do
          let(:schema) { 'banana-schema' }

          it_behaves_like 'a Presto trace'
        end

        context 'with nil schema' do
          let(:schema) { nil }

          it_behaves_like 'a Presto trace'
        end

        context 'with an empty schema' do
          let(:schema) { '' }

          it_behaves_like 'a Presto trace'
        end

        context 'with a different catalog' do
          let(:catalog) { 'eatons' }

          it_behaves_like 'a Presto trace'
        end

        context 'with a nil catalog' do
          let(:schema) { nil }
          let(:catalog) { nil }

          it_behaves_like 'a Presto trace'
        end

        context 'with a different user' do
          let(:user) { 'banana' }

          it_behaves_like 'a Presto trace'
        end

        context 'with a different time zone' do
          let(:time_zone) { 'Antarctica/Troll' }

          it_behaves_like 'a Presto trace'
        end

        context 'with a nil time zone' do
          let(:time_zone) { nil }

          it_behaves_like 'a Presto trace'
        end

        context 'with a diferent language' do
          let(:language) { 'Français' }

          it_behaves_like 'a Presto trace'
        end

        context 'with a nil language' do
          let(:language) { nil }

          it_behaves_like 'a Presto trace'
        end

        context 'with a different http proxy' do
          let(:http_proxy) { 'proxy.bar.foo:8080' }

          it_behaves_like 'a Presto trace'
        end

        context 'with a nil http proxy' do
          let(:http_proxy) { nil }

          it_behaves_like 'a Presto trace'
        end

        context 'with a different model version' do
          let(:model_version) { '0.173' }

          it_behaves_like 'a Presto trace'
        end
