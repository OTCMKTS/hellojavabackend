require 'spec_helper'
require 'datadog/profiling'

RSpec.describe Datadog::Profiling do
  extend ConfigurationHelpers

  describe '.start_if_enabled' do
    subject(:start_if_enabled) { described_class.start_if_enabled }

    before do
      allow(Datadog.send(:components)).to receive(:profiler).and_return(result)
    end

    context 'with the profiler instance available' do
      let(:result) { instance_double('Datadog::Profiling::Profiler') }
      it 'starts the profiler instance' do
        expect(result).to receive(:start)
        is_expected.to be(true)
      end
    end

    context 'with the profiler instance not available' do
      let(:result) { nil }
      it { is_expected.to be(false) }
    end
  end

  describe '.allocation_count' do
    subject(:allocation_count) { described_class.allocation_count }

    context 'when profiling is supported' do
      before do
        skip('Test only runs on setups where profiling is supported') unless described_class.supported?
      end

      it 'delegates to the CpuAndWallTimeWorker' do
        expect(Datadog::Profiling::Collectors::CpuAndWallTimeWorker)
          .to receive(:_native_allocation_count).and_return(:allocation_count_result)

        expect(allocation_count).to be :allocation_count_result
      end
    end

    context 'when profiling is not supported' do
      before do
        skip('Test only runs on setups where profiling is not supported') if described_class.supported?
      end

      it 'does not reference the CpuAndWallTimeWorker' do
        if defined?(Datadog::Profiling::Collectors::CpuAndWallTimeWorker)
          without_partial_double_verification do
            expect(Datadog::Profiling::Collectors::CpuAndWallTimeWorker).to_not receive(:_native_allocation_count)
          end
        end

        allocation_count
      end

      it { is_expected.to be nil }
    end
  end

  describe '::supported?' do
    subject(:supported?) { described_class.supported? }

    context 'when there is an unsupported_reason' do
      before { allow(described_class).to receive(:unsupported_reason).and_return('Unsupported, sorry :(') }

      it { is_expected.to be false }
    end

    context 'when there is no unsupported_reason' do
      before { allow(described_class).to receive(:unsupported_reason).and_return(nil) }

      it { is_expected.to be true }
    end
  end

  describe '::unsupported_reason' do
    subject(:unsupported_reason) { described_class.unsupported_reason }

    context 'when the profiling native library was not compiled' do
      before do
        expect(described_class).to receive(:try_reading_skipped_reason_file).and_return('fake skipped reason')
      end

      it { is_expected.to include 'missing support for the Continuous Profiler' }
    end

    context 'when the profiling native library was compiled' do
      before do
        expect(described_class)