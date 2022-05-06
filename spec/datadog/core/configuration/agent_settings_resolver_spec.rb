require 'datadog/core/configuration/agent_settings_resolver'
require 'datadog/core/configuration/settings'

RSpec.describe Datadog::Core::Configuration::AgentSettingsResolver do
  around { |example| ClimateControl.modify(default_environment.merge(environment)) { example.run } }

  let(:default_environment) do
    {
      'DD_AGENT_HOST' => nil,
      'DD_TRACE_AGENT_PORT' => nil,
      'DD_TRACE_AGENT_URL' => nil
    }
  end
  let(:environment) { {} }
  let(:ddtrace_settings) { Datadog::Core::Configuration::Settings.new }
  let(:logger) { instance_double(Datadog::Core::Logger) }

  let(:settings) do
    {
      adapter: adapter,
      ssl: false,
      hostname: hostname,
      port: port,
      uds_path: uds_path,
      timeout_seconds: nil,
      deprecated_for_removal_transport_configuration_proc: nil,
    }
  end

  let(:adapter) { :net_http }
  let(:hostname) { '127.0.0.1' }
  let(:port) { 8126 }
  let(:uds_path) { nil }

  before do
    # Environment does not have existing unix socket for the base testing case
    allow(File).to receive(:exist?).with('/var/run/datadog/apm.socket').and_return(false)
  end

  subject(:resolver) { described_class.call(ddtrace_settings, logger: logger) }

  context 'by default' do
    it 'contacts the agent using the http adapter, using hostname 127.0.0.1 and port 8126' do
      expect(resolver).to have_attributes settings
    end

    context 'with default unix socket present' do
      before do
        expect(File).to receive(:exist?).with('/var/run/datadog/apm.socket').and_return(true)
      end

      let(:adapter) { :unix }
      let(:uds_path) { '/var/run/datadog/apm.socket' }
      let(:hostname) { nil }
      let(:port) { nil }

      it 'configures the agent to connect to unix:/var/run/datadog/apm.socket' do
        expect(resolver).to have_attributes(
          **settings,
          adapter: :unix,
          uds_path: '/var/run/datadog/apm.socket',
          hostname: nil,
          port: nil,
        )
      end
    end
  end

  describe 'http adapter hostname' do
    context 'when a custom hostname is specified via the DD_AGENT_HOST environment variable' do
      let(:environment) { { 'DD_AGENT_HOST' => 'custom-hostname' } }

      it 'contacts the agent using the http adapter, using the custom hostname' do
        expect(resolver).to have_attributes(**settings, hostname: 'custom-hostname')
      end
    end

    context 'when a custom hostname is specified via code using "agent.host ="' do
      before do
        ddtrace_settings.agent.host = 'custom-hostname'
      end

      it 'contacts the agent using the http adapter, using the custom hostname' do
        expect(resolver).to have_attributes(**settings, hostname: 'custom-hostname')
      end
    end

    context 'when a custom hostname is specified via the DD_TRACE_AGENT_URL environment variable' do
      let(:environment) { { 'D