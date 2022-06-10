require 'spec_helper'

require 'ddtrace'
require 'datadog/core/workers/runtime_metrics'

RSpec.describe Datadog::Core::Workers::RuntimeMetrics do
  subject(:worker) { described_class.new(options) }

  let(:metrics) { instance_double(Datadog::Core::Runtime::Metrics, close: nil) }
  let(:options) { { metrics: metrics, enabled: true } }

  before { allow(metrics).to receive(:flush) }

  after { worker.stop(true, 1) }

  describe '#initialize' do
    it { expect(worker).to be_a_kind_of(Datadog::Core::Workers::Polling) }

    context 'by default' do
      subject(:worker) { described_class.new }

      it { expect(worker.enabled?).to be false }
      it { expect(worker.loop_base_interval).to eq 10 }
      it { expect(worker.loop_back_off_ratio).to eq 1.2 }
      it { expect(worker.loop_back_off_max).to eq 30 }
    end

    context 'when :enabled is given' do
      let(:options) { super().merge(enabled: true) }

      it { expect(worker.enabled?).to be true }
    end

    context 'when :enabled is not given' do
      before { options.delete(:enabled) }

      it { expect(worker.enabled?).to be false }
    end

    context 'when :interval is given' do
      let(:value) { double }
      let(:options) { super().merge(interval: value) }

      it { expect(worker.loop_base_interval).to be value }
    end

    context 'when :back_off_ratio is given' do
      let(:value) { double }
      let(:options) { super().merge(back_off_ratio: value) }

      it { expect(worker.loop_back_off_ratio).to be value }
    end

    context 'when :back_off_max is given' do
      let(:value) { double }
      let(:options) { super().merge(back_off_max: value) }

      it { expect(worker.loop_back_off_max).to be value }
    end
  end

  describe '#perform' do
    subject(:perform) { worker.perform }

    after { worker.stop(true, 5) }

    context 'when #enabled? is true' do
      before { allow(worker).to receive(:enabled?).and_return(true) }

      it 'starts a worker thread' do
        perform
        expect(worker).to have_attributes(
          metrics: metrics,
          run_async?: true,
          running?: true,
          started?: true,
          forked?: false,
          fork_policy: Datadog::Core::Workers::Async::Thread::FORK_POLICY_STOP,
          result: nil
        )
      end
    end
  end

  describe '#enabled=' do
    subject(:set_enabled_value) { worker.enabled = value }

    after { worker.stop(true, 5) }

    context 'when not running' do
      before do
        worker.enabled = false
        allow(worker).to receive(:perform)
        allow(worker).to re