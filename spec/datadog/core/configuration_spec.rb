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
          let(:ini