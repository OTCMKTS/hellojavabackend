
require 'spec_helper'

require 'securerandom'
require 'logger'

require 'datadog/core/configuration/settings'
require 'datadog/core/environment/ext'
require 'datadog/core/runtime/ext'
require 'datadog/core/utils/time'
require 'datadog/profiling/ext'

RSpec.describe Datadog::Core::Configuration::Settings do
  subject(:settings) { described_class.new(options) }

  let(:options) { {} }

  describe '#api_key' do
    subject(:api_key) { settings.api_key }

    context "when #{Datadog::Core::Environment::Ext::ENV_API_KEY}" do
      around do |example|
        ClimateControl.modify(Datadog::Core::Environment::Ext::ENV_API_KEY => api_key_env) do
          example.run
        end
      end

      context 'is not defined' do
        let(:api_key_env) { nil }

        it { is_expected.to be nil }
      end

      context 'is defined' do
        let(:api_key_env) { SecureRandom.uuid.delete('-') }

        it { is_expected.to eq(api_key_env) }
      end
    end
  end

  describe '#api_key=' do
    subject(:set_api_key) { settings.api_key = api_key }

    context 'when given a value' do
      let(:api_key) { SecureRandom.uuid.delete('-') }

      before { set_api_key }

      it { expect(settings.api_key).to eq(api_key) }
    end
  end

  describe '#diagnostics' do
    describe '#debug' do
      subject(:debug) { settings.diagnostics.debug }

      it { is_expected.to be false }

      context "when #{Datadog::Core::Configuration::Ext::Diagnostics::ENV_DEBUG_ENABLED}" do
        around do |example|
          ClimateControl.modify(Datadog::Core::Configuration::Ext::Diagnostics::ENV_DEBUG_ENABLED => environment) do
            example.run
          end
        end

        context 'is not defined' do
          let(:environment) { nil }

          it { is_expected.to be false }
        end

        context 'is set to true' do
          let(:environment) { 'true' }

          it { is_expected.to be true }
        end

        context 'is set to false' do
          let(:environment) { 'false' }

          it { is_expected.to be false }
        end
      end
    end

    describe '#debug=' do
      context 'enabled' do
        subject(:set_debug) { settings.diagnostics.debug = true }

        after { settings.diagnostics.debug = false }

        it 'updates the #debug setting' do
          expect { set_debug }.to change { settings.diagnostics.debug }.from(false).to(true)
        end

        it 'requires debug dependencies' do
          expect_any_instance_of(Object).to receive(:require).with('pp')
          set_debug
        end
      end

      context 'disabled' do
        subject(:set_debug) { settings.diagnostics.debug = false }

        it 'does not require debug dependencies' do
          expect_any_instance_of(Object).to_not receive(:require)
          set_debug
        end
      end
    end

    describe '#health_metrics' do
      describe '#enabled' do
        subject(:enabled) { settings.diagnostics.health_metrics.enabled }

        context "when #{Datadog::Core::Configuration::Ext::Diagnostics::ENV_HEALTH_METRICS_ENABLED}" do
          around do |example|
            ClimateControl.modify(
              Datadog::Core::Configuration::Ext::Diagnostics::ENV_HEALTH_METRICS_ENABLED => environment
            ) do
              example.run
            end
          end

          context 'is not defined' do
            let(:environment) { nil }

            it { is_expected.to be false }
          end

          context 'is defined' do
            let(:environment) { 'true' }

            it { is_expected.to be true }
          end
        end
      end

      describe '#enabled=' do
        it 'changes the #enabled setting' do
          expect { settings.diagnostics.health_metrics.enabled = true }
            .to change { settings.diagnostics.health_metrics.enabled }
            .from(false)
            .to(true)
        end
      end

      describe '#statsd' do
        subject(:statsd) { settings.diagnostics.health_metrics.statsd }

        it { is_expected.to be nil }
      end

      describe '#statsd=' do
        let(:statsd) { double('statsd') }

        it 'changes the #statsd setting' do
          expect { settings.diagnostics.health_metrics.statsd = statsd }
            .to change { settings.diagnostics.health_metrics.statsd }
            .from(nil)
            .to(statsd)
        end
      end
    end
  end

  describe '#env' do
    subject(:env) { settings.env }

    context "when #{Datadog::Core::Environment::Ext::ENV_ENVIRONMENT}" do
      around do |example|
        ClimateControl.modify(Datadog::Core::Environment::Ext::ENV_ENVIRONMENT => environment) do
          example.run
        end
      end

      context 'is not defined' do
        let(:environment) { nil }

        it { is_expected.to be nil }
      end

      context 'is defined' do
        let(:environment) { 'env-value' }

        it { is_expected.to eq(environment) }
      end
    end

    context 'when an env tag is defined in DD_TAGS' do
      around do |example|
        ClimateControl.modify(Datadog::Core::Environment::Ext::ENV_TAGS => 'env:env-from-tag') do
          example.run
        end
      end

      it 'uses the env from DD_TAGS' do
        is_expected.to eq('env-from-tag')
      end

      context 'and defined via DD_ENV' do
        around do |example|
          ClimateControl.modify(Datadog::Core::Environment::Ext::ENV_ENVIRONMENT => 'env-from-dd-env') do
            example.run
          end
        end

        it 'uses the env from DD_ENV' do
          is_expected.to eq('env-from-dd-env')
        end
      end
    end
  end

  describe '#env=' do
    subject(:set_env) { settings.env = env }

    context 'when given a value' do
      let(:env) { 'custom-env' }

      before { set_env }

      it { expect(settings.env).to eq(env) }
    end
  end

  describe '#logger' do
    describe '#instance' do
      subject(:instance) { settings.logger.instance }

      it { is_expected.to be nil }
    end

    describe '#instance=' do
      let(:logger) do
        double(
          :logger,
          debug: true,
          info: true,
          warn: true,
          error: true,
          level: true
        )
      end

      it 'updates the #instance setting' do
        expect { settings.logger.instance = logger }
          .to change { settings.logger.instance }
          .from(nil)
          .to(logger)
      end
    end

    describe '#level' do
      subject(:level) { settings.logger.level }

      it { is_expected.to be ::Logger::INFO }
    end

    describe 'level=' do
      let(:level) { ::Logger::DEBUG }

      it 'changes the #statsd setting' do
        expect { settings.logger.level = level }
          .to change { settings.logger.level }
          .from(::Logger::INFO)
          .to(level)
      end
    end
  end

  describe '#profiling' do
    describe '#enabled' do
      subject(:enabled) { settings.profiling.enabled }

      context "when #{Datadog::Profiling::Ext::ENV_ENABLED}" do
        around do |example|
          ClimateControl.modify(Datadog::Profiling::Ext::ENV_ENABLED => environment) do
            example.run
          end
        end

        context 'is not defined' do
          let(:environment) { nil }

          it { is_expected.to be false }
        end

        context 'is defined' do
          let(:environment) { 'true' }

          it { is_expected.to be true }
        end
      end
    end

    describe '#enabled=' do
      it 'updates the #enabled setting' do
        expect { settings.profiling.enabled = true }
          .to change { settings.profiling.enabled }
          .from(false)
          .to(true)
      end
    end

    describe '#exporter' do
      describe '#transport' do
        subject(:transport) { settings.profiling.exporter.transport }

        it { is_expected.to be nil }
      end

      describe '#transport=' do
        let(:transport) { double('transport') }

        it 'updates the #transport setting' do
          expect { settings.profiling.exporter.transport = transport }
            .to change { settings.profiling.exporter.transport }
            .from(nil)
            .to(transport)
        end
      end
    end

    describe '#advanced' do
      describe '#max_events' do
        subject(:max_events) { settings.profiling.advanced.max_events }

        it { is_expected.to eq(32768) }
      end

      describe '#max_events=' do
        it 'updates the #max_events setting' do
          expect { settings.profiling.advanced.max_events = 1234 }
            .to change { settings.profiling.advanced.max_events }
            .from(32768)
            .to(1234)
        end
      end

      describe '#max_frames' do
        subject(:max_frames) { settings.profiling.advanced.max_frames }

        context "when #{Datadog::Profiling::Ext::ENV_MAX_FRAMES}" do
          around do |example|
            ClimateControl.modify(Datadog::Profiling::Ext::ENV_MAX_FRAMES => environment) do
              example.run
            end
          end

          context 'is not defined' do
            let(:environment) { nil }

            it { is_expected.to eq(400) }
          end

          context 'is defined' do
            let(:environment) { '123' }

            it { is_expected.to eq(123) }
          end
        end
      end

      describe '#max_frames=' do
        it 'updates the #max_frames setting' do
          expect { settings.profiling.advanced.max_frames = 456 }
            .to change { settings.profiling.advanced.max_frames }
            .from(400)
            .to(456)
        end
      end