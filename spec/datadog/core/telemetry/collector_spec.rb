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
            