require 'spec_helper'
require 'datadog/profiling/spec_helper'

require 'logger'

require 'datadog/core/configuration/agent_settings_resolver'
require 'datadog/core/configuration/components'
require 'datadog/core/diagnostics/environment_logger'
require 'datadog/core/diagnostics/health'
require 'datadog/core/logger'
require 'datadog/core/telemetry/client'
require 'datadog/core/runtime/metrics'
require 'datadog/core/workers/runtime_metrics'
require 'datadog/profiling'
require 'datadog/profiling/collectors/code_provenance'
require 'datadog/profiling/collectors/old_stack'
require 'datadog/profiling/profiler'
require 'datadog/profiling/old_recorder'
require 'datadog/profiling/exporter'
require 'datadog/profiling/scheduler'
require 'datadog/profiling/tasks/setup'
require 'datadog/profiling/trace_identifiers/helper'
require 'datadog/statsd'
require 'datadog/tracing/flush'
require 'datadog/tracing/sampling/all_sampler'
require 'datadog/tracing/sampling/priority_sampler'
require 'datadog/tracing/sampling/rate_by_service_sampler'
require 'datadog/tracing/sampling/rule_sampler'
require 'datadog/tracing/sync_writer'
require 'datadog/tracing/tracer'
require 'datadog/tracing/writer'
require 'ddtrace/transport/http/adapters/net'

RSpec.describe Datadog::Core::Configuration::Components do
  subject(:components) { described_class.new(settings) }

  let(:settings) { Datadog::Core::Configuration::Settings.new }
  let(:agent_settings) { Datadog::Core::Configuration::AgentSettingsResolver.call(settings, logger: nil) }

  let(:profiler_setup_task) { Datadog::Profiling.supported? ? instance_double(Datadog::Profiling::Tasks::Setup) : nil }

  before do
    # Ensure the real task never gets run (so it doesn't apply our thread patches and other extensions to our test env)
    if Datadog::Profiling.supported?
      allow(Datadog::Profiling::Tasks::Setup).to receive(:new).and_return(profiler_setup_task)
    end
    allow(Datadog::Statsd).to receive(:new) { instance_double(Datadog::Statsd) }
  end

  describe '::new' do
    let(:logger) { instance_double(Datadog::Core::Logger) }
    let(:tracer) { instance_double(Datadog::Tracing::Tracer) }
    let(:profiler) { Datadog::Profiling.supported? ? instance_double(Datadog::Profiling::Profiler) : nil }
    let(:runtime_metrics) { instance_double(Datadog::Core::Workers::RuntimeMetrics) }
    let(:health_metrics) { instance_double(Datadog::Core::Diagnostics::Health::Metrics) }

    before do
      expect(described_class).to receive(:build_logger)
        .with(settings)
        .and_return(logger)

      expect(described_class).to receive(:build_tracer)
        .with(settings, instance_of(Datadog::Core::Configuration::AgentSettingsResolver::AgentSettings))
        .and_return(tracer)

      expect(described_class).to receive(:build_profiler)
        .with(
          settings,
          instance_of(Datadog::Core::Configuration::AgentSettingsResolver::AgentSettings),
          tracer
        )
        .and_return(profiler)

      expect(described_class).to receive(:build_runtime_metrics_worker)
        .with(settings)
        .and_return(runtime_metrics)

      expect(described_class).to receive(:build_health_metrics)
        .with(settings)
        .and_return(health_metrics)
    end

    after do
      components.telemetry.worker.stop(true)
      components.telemetry.worker.join
    end

    it do
      expect(components.logger).to be logger
      expect(components.tracer).to be tracer
      expect(components.profiler).to be profiler
      expect(components.runtime_metrics).to be runtime_metrics
      expect(components.health_metrics).to be health_metrics
    end
  end

  describe '::build_health_metrics' do
    subject(:build_health_metrics) { described_class.build_health_metrics(settings) }

    context 'given settings' do
      shared_examples_for 'new health metrics' do
        let(:health_metrics) { instance_double(Datadog::Core::Diagnostics::Health::Metrics) }
        let(:default_options) { { enabled: settings.diagnostics.health_metrics.enabled } }
        let(:options) { {} }

        before do
          expect(Datadog::Core::Diagnostics::Health::Metrics).to receive(:new)
            .with(default_options.merge(options))
            .and_return(health_metrics)
        end

        it { is_expected.to be(health_metrics) }
      end

      context 'by default' do
        it_behaves_like 'new health metrics'
      end

      context 'with :enabled' do
        let(:enabled) { double('enabled') }

        before do
          allow(settings.diagnostics.health_metrics)
            .to receive(:enabled)
            .and_return(enabled)
        end

        it_behaves_like 'new health metrics' do
          let(:options) { { enabled: enabled } }
        end
      end

      context 'with :statsd' do
        let(:statsd) { instance_double(Datadog::Statsd) }

        before do
          allow(settings.diagnostics.health_metrics)
            .to receive(:statsd)
            .and_return(statsd)
        end

        it_behaves_like 'new health metrics' do
          let(:options) { { statsd: statsd } }
        end
      end
    end
  end

  describe '::build_logger' do
    subject(:build_logger) { described_class.build_logger(settings) }

    context 'given an instance' do
      let(:instance) { instance_double(Datadog::Core::Logger) }

      before do
        expect(settings.logger).to receive(:instance)
          .and_return(instance)

        expect(instance).to receive(:level=)
          .with(settings.logger.level)
      end

      it 'uses the logger instance' do
        expect(Datadog::Core::Logger).to_not receive(:new)
        is_expected.to be(instance)
      end
    end

    context 'given settings' do
      shared_examples_for 'new logger' do
        let(:logger) { instance_double(Datadog::Core::Logger) }
        let(:level) { settings.logger.level }

        before do
          expect(Datadog::Core::Logger).to receive(:new)
            .with($stdout)
            .and_return(logger)

          expect(logger).to receive(:level=).with(level)
        end

        it { is_expected.to be(logger) }
      end

      context 'by default' do
        it_behaves_like 'new logger'
      end

      context 'with :level' do
        let(:level) { double('level') }

        before do
          allow(settings.logger)
            .to receive(:level)
            .and_return(level)
        end

        it_behaves_like 'new logger'
      end

      context 'with debug: true' do
        before { settings.diagnostics.debug = true }

        it_behaves_like 'new logger' do
          let(:level) { ::Logger::DEBUG }
        end

        context 'and a conflicting log level' do
          before do
            allow(settings.logger)
              .to receive(:level)
              .and_return(::Logger::INFO)
          end

          it_behaves_like 'new logger' do
            let(:level) { ::Logger::DEBUG }
          end
        end
      end
    end
  end

  describe '::build_telemetry' do
    subject(:build_telemetry) { described_class.build_telemetry(settings) }

    context 'given settings' do
      let(:telemetry_client) { instance_double(Datadog::Core::Telemetry::Client) }
      let(:default_options) { { enabled: enabled } }
      let(:enabled) { true }

      before do
        expect(Datadog::Core::Telemetry::Client).to receive(:new).with(default_options).and_return(telemetry_client)
        allow(settings.telemetry).to receive(:enabled).and_return(enabled)
      end

      it { is_expected.to be(telemetry_client) }

      context 'with :enabled' do
        let(:enabled) { double('enabled') }

        it { is_expected.to be(telemetry_client) }
      end
    end
  end

  describe '::build_runtime_metrics' do
    subject(:build_runtime_metrics) { described_class.build_runtime_metrics(settings) }

    context 'given settings' do
      shared_examples_for 'new runtime metrics' do
        let(:runtime_metrics) { instance_double(Datadog::Core::Runtime::Metrics) }
        let(:default_options) { { enabled: settings.runtime_metrics.enabled, services: [settings.service] } }
        let(:options) { {} }

        before do
          expect(Datadog::Core::Runtime::Metrics).to receive(:new)
            .with(default_options.merge(options))
            .and_return(runtime_metrics)
        end

        it { is_expected.to be(runtime_metrics) }
      end

      context 'by default' do
        it_behaves_like 'new runtime metrics'
      end

      context 'with :enabled' do
        let(:enabled) { double('enabled') }

        before do
          allow(settings.runtime_metrics)
            .to receive(:enabled)
            .and_return(enabled)
        end

        it_behaves_like 'new runtime metrics' do
          let(:options) { { enabled: enabled } }
        end
      end

      context 'with :service' do
        let(:service) { double('service') }

        before do
          allow(settings)
            .to receive(:service)
            .and_return(service)
        end

        it_behaves_like 'new runtime metrics' do
          let(:options) { { services: [service] } }
        end
      end

      context 'with :statsd' do
        let(:statsd) { instance_double(::Datadog::Statsd) }

        before do
          allow(settings.runtime_metrics)
            .to receive(:statsd)
            .and_return(statsd)
        end

        it_behaves_like 'new runtime metrics' do
          let(:options) { { statsd: statsd } }
        end
      end
    end
  end

  describe '::build_runtime_metrics_worker' do
    subject(:build_runtime_metrics_worker) { described_class.build_runtime_metrics_worker(settings) }

    context 'given settings' do
      shared_examples_for 'new runtime metrics worker' do
        let(:runtime_metrics_worker) { instance_double(Datadog::Core::Workers::RuntimeMetrics) }
        let(:runtime_metrics) { instance_double(Datadog::Core::Runtime::Metrics) }
        let(:default_options) do
          {
            enabled: settings.runtime_metrics.enabled,
            metrics: runtime_metrics
          }
        end
        let(:options) { {} }

        before do
          allow(described_class).to receive(:build_runtime_metrics)
            .with(settings)
            .and_return(runtime_metrics)

          expect(Datadog::Core::Workers::RuntimeMetrics).to receive(:new)
            .with(default_options.merge(options))
            .and_return(runtime_metrics_worker)
        end

        it { is_expected.to be(runtime_metrics_worker) }
      end

      context 'by default' do
        it_behaves_like 'new runtime metrics worker'
      end

      context 'with :enabled' do
        let(:enabled) { double('enabled') }

        before do
          allow(settings.runtime_metrics)
            .to