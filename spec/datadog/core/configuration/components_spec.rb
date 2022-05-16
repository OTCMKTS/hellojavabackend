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
            .to receive(:enabled)
            .and_return(enabled)
        end

        it_behaves_like 'new runtime metrics worker' do
          let(:options) { { enabled: enabled } }
        end
      end

      context 'with :opts' do
        let(:opts) { { custom_option: :custom_value } }

        before do
          allow(settings.runtime_metrics)
            .to receive(:opts)
            .and_return(opts)
        end

        it_behaves_like 'new runtime metrics worker' do
          let(:options) { opts }
        end
      end
    end
  end

  describe '::build_tracer' do
    subject(:build_tracer) { described_class.build_tracer(settings, agent_settings) }

    context 'given an instance' do
      let(:instance) { instance_double(Datadog::Tracing::Tracer) }

      before do
        expect(settings.tracing).to receive(:instance)
          .and_return(instance)
      end

      it 'uses the tracer instance' do
        expect(Datadog::Tracing::Tracer).to_not receive(:new)
        is_expected.to be(instance)
      end
    end

    context 'given settings' do
      shared_examples_for 'new tracer' do
        let(:tracer) { instance_double(Datadog::Tracing::Tracer) }
        let(:writer) { Datadog::Tracing::Writer.new }
        let(:trace_flush) { be_a(Datadog::Tracing::Flush::Finished) }
        let(:sampler) do
          if defined?(super)
            super()
          else
            lambda do |sampler|
              expect(sampler).to be_a(Datadog::Tracing::Sampling::PrioritySampler)
              expect(sampler.pre_sampler).to be_a(Datadog::Tracing::Sampling::AllSampler)
              expect(sampler.priority_sampler.rate_limiter.rate).to eq(settings.tracing.sampling.rate_limit)
              expect(sampler.priority_sampler.default_sampler).to be_a(Datadog::Tracing::Sampling::RateByServiceSampler)
            end
          end
        end
        let(:span_sampler) { be_a(Datadog::Tracing::Sampling::Span::Sampler) }
        let(:default_options) do
          {
            default_service: settings.service,
            enabled: settings.tracing.enabled,
            trace_flush: trace_flush,
            tags: settings.tags,
            sampler: sampler,
            span_sampler: span_sampler,
            writer: writer,
          }
        end

        let(:options) { defined?(super) ? super() : {} }
        let(:tracer_options) { default_options.merge(options) }
        let(:writer_options) { defined?(super) ? super() : {} }

        before do
          expect(Datadog::Tracing::Tracer).to receive(:new)
            .with(tracer_options)
            .and_return(tracer)

          allow(Datadog::Tracing::Writer).to receive(:new)
            .with(agent_settings: agent_settings, **writer_options)
            .and_return(writer)
        end

        after do
          writer.stop
        end

        it { is_expected.to be(tracer) }
      end

      shared_examples 'event publishing writer' do
        it 'subscribes to writer events' do
          expect(writer.events.after_send).to receive(:subscribe) do |&block|
            expect(block)
              .to be(
                Datadog::Core::Configuration::Components
                  .singleton_class::WRITER_RECORD_ENVIRONMENT_INFORMATION_CALLBACK
              )
          end

          build_tracer
        end
      end

      shared_examples 'event publishing writer and priority sampler' do
        it_behaves_like 'event publishing writer'

        before do
          allow(writer.events.after_send).to receive(:subscribe)
        end

        let(:sampler_rates_callback) { -> { double('sampler rates callback') } }

        it 'subscribes to writer events' do
          expect(described_class).to receive(:writer_update_priority_sampler_rates_callback)
            .with(tracer_options[:sampler]).and_return(sampler_rates_callback)

          expect(writer.events.after_send).to receive(:subscribe) do |&block|
            expect(block)
              .to be(
                Datadog::Core::Configuration::Components
                                       .singleton_class::WRITER_RECORD_ENVIRONMENT_INFORMATION_CALLBACK
              )
          end

          expect(writer.events.after_send).to receive(:subscribe) do |&block|
            expect(block).to be(sampler_rates_callback)
          end
          build_tracer
        end
      end

      context 'by default' do
        it_behaves_like 'new tracer' do
          it_behaves_like 'event publishing writer and priority sampler'
        end
      end

      context 'with :enabled' do
        let(:enabled) { double('enabled') }

        before do
          allow(settings.tracing)
            .to receive(:enabled)
            .and_return(enabled)
        end

        it_behaves_like 'new tracer' do
          let(:options) { { enabled: enabled } }
          it_behaves_like 'event publishing writer and priority sampler'
        end
      end

      context 'with :env' do
        let(:env) { double('env') }

        before do
          allow(settings)
            .to receive(:env)
            .and_return(env)
        end

        it_behaves_like 'new tracer' do
          let(:options) { { tags: { 'env' => env } } }
          it_behaves_like 'event publishing writer and priority sampler'
        end
      end

      context 'with :partial_flush :enabled' do
        let(:enabled) { true }

        before do
          allow(settings.tracing.partial_flush)
            .to receive(:enabled)
            .and_return(enabled)
        end

        it_behaves_like 'new tracer' do
          let(:options) { { trace_flush: be_a(Datadog::Tracing::Flush::Partial) } }
          it_behaves_like 'event publishing writer and priority sampler'
        end

        context 'with :partial_flush :min_spans_threshold' do
          let(:min_spans_threshold) { double('min_spans_threshold') }

          before do
            allow(settings.tracing.partial_flush)
              .to receive(:min_spans_threshold)
              .and_return(min_spans_threshold)
          end

          it_behaves_like 'new tracer' do
            let(:options) do
              { trace_flush: be_a(Datadog::Tracing::Flush::Partial) &
                have_attributes(min_spans_for_partial: min_spans_threshold) }
            end

            it_behaves_like 'event publishing writer and priority sampler'
          end
        end
      end

      context 'with :priority_sampling' do
        before do
          allow(settings.tracing)
            .to receive(:priority_sampling)
            .and_return(priority_sampling)
        end

        context 'enabled' do
          let(:priority_sampling) { true }

          it_behaves_like 'new tracer'

          context 'with :sampler' do
            before do
              allow(settings.tracing)
                .to receive(:sampler)
                .and_return(sampler)
            end

            context 'that is a priority sampler' do
              let(:sampler) { Datadog::Tracing::Sampling::PrioritySampler.new }

              it_behaves_like 'new tracer' do
                let(:options) { { sampler: sampler } }
                it_behaves_like 'event publishing writer and priority sampler'
              end
            end

            context 'that is not a priority sampler' do
              let(:sampler) { double('sampler') }

              context 'wraps sampler in a priority sampler' do
                it_behaves_like 'new tracer' do
                  let(:options) do
                    { sampler: be_a(Datadog::Tracing::Sampling::PrioritySampler) & have_attributes(
                      pre_sampler: sampler,
                      priority_sampler: be_a(Datadog::Tracing::Sampling::RuleSampler)
                    ) }
                  end

                  it_behaves_like 'event publishing writer and priority sampler'
                end
              end
            end
          end
        end

        context 'disabled' do
          let(:priority_sampling) { false }

          it_behaves_like 'new tracer' do
            let(:options) { { sampler: be_a(Datadog::Tracing::Sampling::RuleSampler) } }
          end

          context 'with :sampler' do
            before do
              allow(settings.tracing)
                .to receive(:sampler)
                .and_return(sampler)
            end

            let(:sampler) { double('sampler') }

            it_behaves_like 'new tracer' do
              let(:options) { { sampler: sampler } }
              it_behaves_like 'event publishing writer'
            end
          end
        end
      end

      context 'with sampling.span_rules' do
        before { allow(settings.tracing.sampling).to receive(:span_rules).and_return(rules) }

        context 'with rules' do
          let(:rules) { '[{"name":"foo"}]' }

          it_behaves_like 'new tracer' do
            let(:options) do
              {
                span_sampler: be_a(Datadog::Tracing::Sampling::Span::Sampler) & have_attributes(
                  rules: [
                    Datadog::Tracing::Sampling::Span::Rule.new(
                      Datadog::Tracing::Sampling::Span::Matcher.new(name_pattern: 'foo')
                    )
                  ]
                )
              }
            end
          end
        end

        context 'without rules' do
          let(:rules) { nil }

          it_behaves_like 'new tracer' do
            let(:options) { { span_sampler: be_a(Datadog::Tracing::Sampling::Span::Sampler) & have_attributes(rules: []) } }
          end
        end
      end

      context 'with :service' do
        let(:service) { double('service') }

        before do
          allow(settings)
            .to receive(:service)
            .and_return(service)
        end

        it_behaves_like 'new tracer' do
          let(:options) { { default_service: service } }
          it_behaves_like 'event publishing writer and priority sampler'
        end
      end

      context 'with :tags' do
        let(:tags) do
          {
            'env' => 'tag_env',
            'version' => 'tag_version'
          }
        end

        before do
          allow(settings)
            .to receive(:tags)
            .and_return(tags)
        end

        it_behaves_like 'new tracer' do
          let(:options) { { tags: tags } }
          it_behaves_like 'event publishing writer and priority sampler'
        end

        context 'with conflicting :env' do
          let(:env) { 'setting_env' }

          before do
            allow(settings)
              .to receive(:env)
              .and_return(env)
          end

          it_behaves_like 'new tracer' do
            let(:options) { { tags: tags.merge('env' => env) } }
            it_behaves_like 'event publishing writer and priority sampler'
          end
        end

        context 'with conflicting :version' do
          let(:version) { 'setting_version' }

          before do
            allow(settings)
              .to receive(:version)
              .and_return(version)
          end

          it_behaves_like 'new tracer' do
            let(:options) { { tags: tags.merge('version' => version) } }
            it_behaves_like 'event publishing writer and priority sampler'
          end
        end
      end

      context 'with :test_mode' do
        let(:sampler) do
          lambda do |sampler|
            expect(sampler).to be_a(Datadog::Tracing::Sampling::PrioritySampler)
            expect(sampler.pre_sampler).to be_a(Datadog::Tracing::Sampling::AllSampler)
            expect(sampler.priority_sampler).to be_a(Datadog::Tracing::Sampling::AllSampler)
          end
        end

        context ':enabled' do
          before do
            allow(settings.tracing.test_mode)
              .to receive(:enabled)
              .and_return(enabled)
          end

          context 'set to true' do
            let(:enabled) { true }
            let(:sync_writer) { Datadog::Tracing::SyncWriter.new }

            before do
              expect(Datadog::Tracing::SyncWriter)
                .to receive(:new)
                .with(agent_settings: agent_settings, **writer_options)
                .and_return(writer)
            end

            context 'and :trace_flush' do
              before do
                allow(settings.tracing.test_mode)
                  .to receive(:trace_flush)
                  .and_return(trace_flush)
              end

              context 'is not set' do
                let(:trace_flush) { nil }

                it_behaves_like 'new tracer' do
                  let(:options) do
                    {
                      writer: kind_of(Datadog::Tracing::SyncWriter)
                    }
                  end
                  let(:writer) { sync_writer }

                  it_behaves_like 'event publishing writer'
                end
              end

              context 'is set' do
                let(:trace_flush) { instance_double(Datadog::Tracing::Flush::Finished) }

                it_behaves_like 'new tracer' do
                  let(:options) do
                    {
                      trace_flush: trace_flush,
                      writer: kind_of(Datadog::Tracing::SyncWriter)
                    }
                  end
                  let(:writer) { sync_writer }

               