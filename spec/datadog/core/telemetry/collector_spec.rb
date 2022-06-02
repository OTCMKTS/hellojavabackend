require 'spec_helper'

require 'datadog/core/configuration'
require 'datadog/core/configuration/agent_settings_resolver'
require 'datadog/core/environment/ext'
require 'datadog/core/telemetry/collector'
require 'datadog/core/telemetry/v1/application'
require 'datadog/core/telemetry/v1/dependency'
require 'datadog/core/telemetry/v1/host'
require 'datadog/core/telemetry/v1/integration'
require 'datadog/core/telemetry/v1/product'
require 'ddtrace/transport/ext'

require 'ddtrace'
require 'ddtrace/version'

RSpec.describe Datadog::Core::Telemetry::Collector do
  let(:dummy_class) { Class.new { extend(Datadog::Core::Telemetry::Collector) } }

  describe '#application' do
    subject(:application) { dummy_class.application }
    let(:env_service) { 'default-service' }

    around do |example|
      ClimateControl.modify(Datadog::Core::Environment::Ext::ENV_SERVICE => env_service) do
        example.run
      end
    end

    it { is_expected.to be_a_kind_of(Datadog::Core::Telemetry::V1::Application) }

    describe ':env' do
      subject(:env) { application.env }

      context 'when DD_ENV not set' do
        it { is_expected.to be_nil }
      end

      context 'when DD_env set' do
        around do |example|
          ClimateControl.modify(Datadog::Core::Environment::Ext::ENV_ENVIRONMENT => 'test_env') do
            example.run
          end
        end

        it { is_expected.to be_a_kind_of(String) }
        it('reads value correctly') { is_expected.to eql('test_env') }
      end
    end

    describe ':service_name' do
      subject(:service_name) { application.service_name }
      let(:env_service) { 'test-service' }

      it { is_expected.to be_a_kind_of(String) }
      it('reads value correctly') { is_expected.to eql('test-service') }
    end

    describe ':service_version' do
      subject(:service_version) { application.service_version }

      context 'when DD_VERSION not set' do
        it { is_expected.to be_nil }
      end

      context 'when DD_VERSION set' do
        around do |example|
          ClimateControl.modify(Datadog::Core::Environment::Ext::ENV_VERSION => '4.2.0') do
            example.run
          end
        end

        it { is_expected.to be_a_kind_of(String) }
        it('reads value correctly') { is_expected.to eql('4.2.0') }
      end
    end

    describe ':products' do
      subject(:products) { application.products }

      context 'when profiling and appsec are disabled' do
        before do
          Datadog.configuration.profiling.enabled = false
          Datadog.configuration.appsec.enabled = false
          stub_const('Datadog::Core::Environment::Ext::TRACER_VERSION', '4.2')
        end

        after do
          Datadog.configuration.profiling.send(:reset!)
          Datadog.configuration.appsec.send(:reset!)
        end

        it { expect(products.appsec).to eq({ version: '4.2' }) }
        it { expect(products.profiler).to eq({ version: '4.2' }) }
      end

      context 'when both profiler and appsec are enabled' do
        require 'datadog/appsec'

        before do
          allow_any_instance_of(Datadog::Profiling::Profiler).to receive(:start) if PlatformHelpers.mri?
          Datadog.configure do |c|
            c.profiling.enabled = true
            c.appsec.enabled = true
          end
        end

        after do
          Datadog.configuration.profiling.send(:reset!)
          Datadog.configuration.appsec.send(:reset!)
        end

        it { is_expected.to be_a_kind_of(Datadog::Core::Telemetry::V1::Product) }
        it { expect(products.appsec).to be_a_kind_of(Hash) }
        it { expect(products.profiler).to be_a_kind_of(Hash) }
      end
    end
  end

  describe '#configurations' do
    subject(:configurations) { dummy_class.configurations }

    it { is_expected.to be_a_kind_of(Hash) }
    it { expect(configurations.values).to_not include(nil) }
    it { expect(configurations.values).to_not include({}) }

    context 'DD_AGENT_HOST' do
      let(:dd_agent_host) { 'ddagent' }

      context 'when set via configuration' do
        before do
          Datadog.configure do |c|
            c.agent.host = dd_agent_host
          end
        end

        it { is_expected.to include(:DD_AGENT_HOST => dd_agent_host) }
      end

      context 'when no value set' do
        let(:dd_agent_host) { nil }
        it { is_expected.to_not include(:DD_AGENT_HOST) }
      end
    end

    context 'DD_AGENT_TRANSPORT' do
      context 'when no configuration variables set' do
        it { is_expected.to include(:DD_AGENT_TRANSPORT => 'TCP') }
      end

      context 'when adapter is type :unix' do
        let(:adapter_type) { Datadog::Transport::Ext::UnixSocket::ADAPTER }

        before do
          allow(Datadog::Core::Configuration::AgentSettingsResolver)
            .to receive(:call).and_return(double('agent settings', :adapter => adapter_type))
        end
        it { is_expected.to include(:DD_AGENT_TRANSPORT => 'UDS') }
      end
    end

    context 'DD_TRACE_SAMPLE_RATE' do
      around do |example|
        ClimateControl.modify DD_TRACE_SAMPLE_RATE: dd_trace_sample_rate do
          example.run
        end
      end

      let(:dd_trace_sample_rate) { nil }
      context 'when set' do
        let(:dd_trace_sample_rate) { '0.2' }
        it { is_expected.to include(:DD_TRACE_SAMPLE_RATE => '0.2') }
      end

      context 'when nil' do
        let(:dd_trace_sample_rate) { nil }
        it { is_expected.to_not include(:DD_TRACE_SAMPLE_RATE) }
      end
    end
  end

  describe '#additional_payload' do
    subject(:additional_payload) { dummy_class.additional_payload }

    it { is_expected.to be_a_kind_of(Hash) }
    it { expect(additional_payload.values).to_not include(nil) }
    it { expect(additional_payload.values).to_not include({}) }

    context 'when environment variable configuration' do
      let(:dd_tracing_analytics_enabled) { 'true' }
      around do |example|
        ClimateControl.modify DD_TRACE_ANALYTICS_ENABLED: dd_tracing_analytics_enabled do
          example.run
        end
      end

      context 'is set' do
        let(:dd_tracing_analytics_enabled) { 'true' }
        it do
          is_expected.to include(
            'tracing.analytics.enabled' => true
          )
        end
      end

      context 'is nil' do
        let(:dd_tracing_analytics_enabled) { nil }
        it { is_expected.to_not include('tracing.analytics.enabled') }
      end
    end

    context 'when profiling is disabled' do
      before do
        Datadog.configuration.profiling.enabled = false
        Datadog.configuration.appsec.enabled = false
      end
      after do
        Datadog.configuration.profiling.send(:reset!)
        Datadog.configuration.appsec.send(:reset!)
      end
      it { is_expected.to include('profiling.enabled' => false) }
    end

    context 'when profiling is enabled' do
      before do
        stub_const('Datadog::Core::Environment::Ext::TRACER_VERSION', '4.2')
        allow_any_instance_of(Datadog::Profiling::Profiler).to receive(:start)
        Datadog.configure do |c|
          c.profiling.enabled = true
        end
      end
      after { Datadog.configuration.profiling.send(:reset!) }

      it { is_expected.to include('profiling.enabled' => true) }
    end

    context 'when appsec is enabled' do
      before do
        require 'datadog/appsec'

        stub_const('Datadog::Core::Environment::Ext::TRACER_VERSION', '4.2')
        Datadog.configure do |c|
          c.appsec.enabled = true
        end
      end
      after { Datadog.configuration.appsec.send(:reset!) }

      i