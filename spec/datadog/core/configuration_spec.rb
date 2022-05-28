require 'spec_helper'
require 'datadog/profiling/spec_helper'

require 'datadog/core/configuration'
require 'datadog/core/pin'
require 'datadog/statsd'
require 'datadog/tracing/tracer'

RSpec.describe Datadog::Core::Configuration do
  let(:default_log_level) { ::Logger::INFO }
  let(:telemetry_client) { instance_double(Datadog::Core::Telemetry::Client) }

  before do
    allow(telemetry_client).to receive(:started!)
    allow(telemetry_client).to receive(:stop!)
    allow(telemetry_client).to receive(:emit_closing!)
    allow(Datadog::Core::Telemetry::Client).to receive(:new).and_return(telemetry_client)
  end

  context 'when extended by a class' do
    subject(:test_class) { stub_const('TestClass', Class.new { extend Datadog::Core::Configuration }) }

    describe '#configure' do
      subject(:configure) { test_class.configure {} }

      context 'when Settings are configured' do
        before do
          allow(Datadog::Core::Configuration::Components).to receive(:new)
            .and_wrap_original do |m, *args|
              new_components = m.call(*args)
              allow(new_components).to receive(:shutdown!)
              allow(new_components).to receive(:startup!)
              new_components
            end
        end

        context 'and components have been initialized' do
          before do
            @original_components = test_class.send(:components)
          end

          it do
            # Components should have changed
            expect { configure }
              .to change { test_class.send(:components) }
              .from(@original_components)

            new_components = test_class.send(:components)
            expect(new_components).to_not be(@original_components)

            # Old components should shutdown, new components should startup
            expect(@original_components)
              .to have_received(:shutdown!)
              .with(new_components)
              .ordered

            expect(new_components)
              .to have_received(:startup!)
              .with(test_class.configuration)
              .ordered

            expect(new_components).to_not have_received(:shutdown!)
          end
        end

        context 'and components have not been initialized' do
          it do
            expect_any_instance_of(Datadog::Core::Configuration::Components)
              .to_not receive(:shutdown!)

            configure

            # Components should have changed
            new_components = test_class.send(:components)

            # New components should startup
            expect(new_components)
              .to have_received(:startup!)
              .with(test_class.configuration)

            expect(new_components).to_not have_received(:shutdown!)
            expect(telemetry_client).to have_received(:started!)
          end
        end
      end

      context 'when debug mode' do
        it 'is toggled with default settings' do
          # Assert initial state
          expect(test_class.logger.level).to be default_log_level

          # Enable
          test_class.configure do |c|
            c.diagnostics.debug = true
            c.logger.instance = Datadog::Core::Logger.new(StringIO.new)
          end

          # Assert state change
          expect(test_class.logger.level).to be ::Logger::DEBUG

          # Disable
          test_class.configure do |c|
            c.diagnostics.debug = false
          end

          # Assert final state
          expect(test_class.logger.level).to be default_log_level
        end

        context 'is disabled with a custom logger in use' do
          let(:initial_log_level) { ::Logger::INFO }
          let(:logger) do
            ::Logger.new(StringIO.new).tap do |l|
              l.level = initial_log_level
            end
          end

          before do
            test_class.configure do |c|
              c.logger.instance = logger
              c.diagnostics.debug = false
            end
          end

          it { expect(logger.level).to be initial_log_level }
        end
      end

      context 'when the logger' do
        context 'is replaced' do
          let(:old_logger) { Datadog::Core::Logger.new($stdout) }
          let(:new_logger) { Datadog::Core::Logger.new($stdout) }

          before do
            # Expect old loggers to NOT be closed, as closing
            # underlying streams can cause problems.
            expect(old_logger).to_not receive(:close)

            test_class.configure { |c| c.logger.instance = old_logger }
            test_class.configure { |c| c.logger.instance = new_logger }
          end

          it 'replaces the old logger' do
            expect(test_class.logger).to be new_logger
          end
        end

        context 'is reused' do
          let(:logger) { Datadog::Core::Logger.new($stdout) }

          before do
            expect(logger).to_not receive(:close)

            test_class.configure { |c| c.logger.instance = logger }
            test_class.configure { |c| c.logger.instance = logger }
          end

          it 'reuses the same logger' do
            expect(test_class.logger).to be logger
          end
        end

        context 'is not changed' do
          let(:logger) { Datadog::Core::Logger.new($stdout) }

          before do
            expect(logger).to_not receive(:close)

            test_class.configure { |c| c.logger.instance = logger }
            test_class.configure { |_c| }
          end

          it 'reuses the same logger' do
            expect(test_class.logger).to be logger
          end
        end
      end

      context 'when the metrics' do
        context 'are replaced' do
          let(:old_statsd) { instance_double(Datadog::Statsd) }
          let(:new_statsd) { instance_double(Datadog::Statsd) }

          before do
            expect(old_statsd).to receive(:close).once

            test_class.configure do |c|
              c.runtime_metrics.statsd = old_statsd
              c.diagnostics.health_metrics.statsd = old_statsd
            end

            test_class.configure do |c|
              c.runtime_metrics.statsd = new_statsd
              c.diagnostics.health_metrics.statsd = new_statsd
            end
          end

          it 'replaces the old Statsd and closes it' do
            expect(test_class.send(:components).runtime_metrics.metrics.statsd).to be new_statsd
            expect(test_class.health_metrics.statsd).to be new_statsd
          end
        end

        context 'have one of a few replaced' do
          let(:old_statsd) { instance_double(Datadog::Statsd) }
          let(:new_statsd) { instance_double(Datadog::Statsd) }

          before do
            # Since its being reused, it should not be closed.
            expect(old_statsd).to_not receive(:close)

            test_class.configure do |c|
              c.runtime_metrics.statsd = old_statsd
              c.diagnostics.health_metrics.statsd = old_statsd
            end

            test_class.configure do |c|
              c.runtime_metrics.statsd = new_statsd
            end
          end

          it 'uses new and old Statsd but does not close the old Statsd' do
            expect(test_class.send(:components).runtime_metrics.metrics.statsd).to be new_statsd
            expect(test_class.health_metrics.statsd).to be old_statsd
          end
        end

        context 'are reused' do
          let(:statsd) { instance_double(Datadog::Statsd) }

          before do
            expect(statsd).to_not receive(:close)

            test_class.configure do |c|
              c.runtime_metrics.statsd = statsd
              c.diagnostics.health_metrics.statsd = statsd
            end

            test_class.configure do |c|
              c.runtime_metrics.statsd = statsd
              c.diagnostics.health_metrics.statsd = statsd
            end
          end

          it 'reuses the same Statsd' do
            expect(test_class.send(:components).runtime_metrics.metrics.statsd).to be statsd
          end
        end

        context 'are not changed' do
          let(:statsd) { instance_double(Datadog::Statsd) }

          before do
            expect(statsd).to_not receive(:close)

            test_class.configure do |c|
              c.runtime_metrics.statsd = statsd
              c.diagnostics.health_metrics.statsd = statsd
            end

            test_class.configure { |_c| }
          end

          it 'reuses the same Statsd' do
            expect(test_class.send(:components).runtime_metrics.metrics.statsd).to be statsd
          end
        end
      end

      context 'when the tracer' do
        context 'is replaced' do
          let(:old_tracer) { Datadog::Tracing::Tracer.new }
          let(:new_tracer) { Datadog::Tracing::Tracer.new }

          before do
            expect(old_tracer).to receive(:shutdown!)

            test_class.send(:configure) { |c| c.tracing.instance = old_tracer }
            test_class.send(:configure) { |c| c.tracing.instance = new_tracer }
          end

          it 'replaces the old tracer and shuts it down' do
            expect(test_class.send(:components).tracer).to be new_tracer
          end
        end

        context 'is reused' do
          let(:tracer) { Datadog::Tracing::Tracer.new }

          before do
            expect(tracer).to_not receive(:shutdown!)

            test_class.send(:configure) { |c| c.tracing.instance = tracer }
            test_class.send(:configure) { |c| c.tracing.instance = tracer }
          end

          it 'reuses the same tracer' do
            expect(test_class.send(:components).tracer).to be tracer
          end
        end

        context 'is not changed' do
          let(:tracer) { Datadog::Tracing::Tracer.new }

          before do
            expect(tracer).to_not receive(:shutdown!)

            test_class.send(:configure) { |c| c.tracing.instance = tracer }
            test_class.send(:configure) { |_c| }
          end

          it 'reuses the same tracer' do
            expect(test_class.send(:components).tracer).to be tracer
          end
        end
      end

      context 'when the profiler' do
        context 'is not changed' do
          before { skip_if_profiling_not_supported(self) }

          context 'and profiling is enabled' do
            before do
              allow(test_class.configuration.profiling)
                .to receive(:enabled)
                .and_return(true)

              allow_any_instance_of(Datadog::Profiling::Profiler)
                .to receive(:start)
              allow_any_instance_of(Datadog::Profiling::Tasks::Setup)
                .to receive(:run)
            end

            it 'starts the profiler' do
              configure
              expect(test_class.send(:components).profiler).to have_received(:start)
            end
          end
        end
      end

      context 'when reconfigured multiple times' do
        context 'with runtime metrics active' do
          before do
            test_class.configure do |c|
              c.runtime_metrics.enabled = true
            end

            @old_runtime_metrics = test_class.send(:components).runtime_metrics

            test_class.configure do |c|
              c.runtime_metrics.enabled = true
            end
          end

          it 'stops the old runtime metrics worker' do
            expect(@old_runtime_metrics.enabled?).to be false
            expect(@old_runtime_metrics.running?).to be false

            expect(test_class.send(:components).runtime_metrics).to_not be @old_runtime_metrics

            expect(test_class.send(:components).runtime_metrics.enabled?).to be true
            expect(test_class.send(:components).runtime_metrics.running?).to be false
          end
        end
      end
    end

    describe '#configure_onto' do
      subject(:configure_onto) { test_class.configure_onto(object, **options) }

      let(:object) { Object.new }
      let(:options) { { any: :thing } }

      it 'attaches a pin to the object' do
        expect(Datadog::Core::Pin)
          .to receive(:set_on)
          .with(object, **options)

        configure_onto
      end
    end

    describe '#configuration_for' do
      subject(:configuration_for) { test_class.configuration_for(object, option_name) }

      let(:object) { double('object') }
      let(:option_name) { :a_setting }

      context 'when the object has not been configured' do
        it { is_expected.to be nil }