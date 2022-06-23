require 'spec_helper'
require 'datadog/profiling/spec_helper'

require 'datadog/profiling/collectors/old_stack'
require 'datadog/profiling/trace_identifiers/helper'
require 'datadog/profiling/old_recorder'
require 'set'
require 'timeout'

RSpec.describe Datadog::Profiling::Collectors::OldStack do
  subject(:collector) { described_class.new(recorder, **options) }

  let(:recorder) { instance_double(Datadog::Profiling::OldRecorder) }
  let(:options) { { max_frames: 50, trace_identifiers_helper: trace_identifiers_helper } }

  let(:buffer) { instance_double(Datadog::Profiling::Buffer) }
  let(:string_table) { Datadog::Core::Utils::StringTable.new }
  let(:backtrace_location_cache) { Datadog::Core::Utils::ObjectSet.new }
  let(:trace_identifiers_helper) do
    instance_double(Datadog::Profiling::TraceIdentifiers::Helper, trace_identifiers_for: nil)
  end

  before do
    skip_if_profiling_not_supported(self)

    allow(recorder)
      .to receive(:[])
      .with(Datadog::Profiling::Events::StackSample)
      .and_return(buffer)

    allow(buffer)
      .to receive(:string_table)
      .and_return(string_table)

    allow(buffer)
      .to receive(:cache)
      .with(:backtrace_locations)
      .and_return(backtrace_location_cache)
  end

  describe '::new' do
    it 'with default settings' do
      is_expected.to have_attributes(
        enabled?: true,
        fork_policy: Datadog::Core::Workers::Async::Thread::FORK_POLICY_RESTART,
        ignore_thread: nil,
        loop_base_interval: described_class::MIN_INTERVAL,
        max_frames: options.fetch(:max_frames),
        max_time_usage_pct: described_class::DEFAULT_MAX_TIME_USAGE_PCT,
        recorder: recorder
      )
    end
  end

  describe '#start' do
    subject(:start) { collector.start }

    before do
      allow(collector).to receive(:perform)
    end

    it 'starts the worker' do
      expect(collector).to receive(:perform)
      start
    end

    describe 'leftover tracking state handling' do
      let(:options) { { **super(), thread_api: thread_api } }

      let(:thread_api) { class_double(Thread, current: Thread.current) }
      let(:thread) { instance_double(Thread, 'Dummy thread') }

      it 'cleans up any leftover tracking state in existing threads' do
        expect(thread_api).to receive(:list).and_return([thread])

        expect(thread).to receive(:thread_variable_set).with(described_class::THREAD_LAST_CPU_TIME_KEY, nil)
        expect(thread).to receive(:thread_variable_set).with(described_class::THREAD_LAST_WALL_CLOCK_KEY, nil)

        start
      end

      context 'Process::Waiter crash regression tests' do
        # See cthread.rb for more details

        before do
          skip 'Test case only applies to MRI Ruby' if RUBY_ENGINE != 'ruby'
        end

        it 'can clean up leftover tracking state on an instance of Process::Waiter without crashing' do
          expect_in_fork do
            expect(thread_api).to receive(:list).and_return([Process.detach(0)])

            start
          end
        end
      end
    end
  end

  describe '#perform' do
    subject(:perform) { collector.perform }

    after do
      collector.stop(true, 0)
      collector.join
    end

    context 'when disabled' do
      before { collector.enabled = false }

      it 'does not start a worker thread' do
        perform

        expect(collector.send(:worker)).to be nil

        expect(collector).to have_attributes(
          run_async?: false,
          running?: false,
          started?: false,
          forked?: false,
          fork_policy: :restart,
          result: nil
        )
      end
    end

    context 'when enabled' do
      before { collector.enabled = true }

      after { collector.terminate }

      it 'starts a worker thread' do
        allow(collector).to receive(:collect_events)

        perform

        expect(collector.send(:worker)).to be_a_kind_of(Thread)
        try_wait_until { collector.running? }

        expect(collector).to have_attributes(
          run_async?: true,
          running?: true,
          started?: true,
          forked?: false,
          fork_policy: :restart,
          result: nil
        )
      end
    end
  end

  describe '#collect_and_wait' do
    subject(:collect_and_wait) { collector.collect_and_wait }

    let(:collect_time) { 0.05 }
    let(:updated_wait_time) { rand }

    before do
      expect(collector).to receive(:collect_events)
      allow(collector).to receive(:compute_wait_time)
        .with(collect_time)
        .and_return(updated_wait_time)

      allow(Datadog::Core::Utils::Time).to receive(:measure) do |&block|
        block.call
        collect_time
      end
    end

    it 'changes its wait interval after collecting' do
      expect(collector).to receive(:loop_wait_time=)
        .with(updated_wait_time)

      collect_and_wait
    end
  end

  describe '#collect_events' do
    let(:options) { { **super(), thread_api: thread_api, max_threads_sampled: max_threads_sampled } }
    let(:thread_api) { class_double(Thread, current: Thread.current) }
    let(:threads) { [Thread.current] }
    let(:max_threads_sampled) { 3 }

    subject(:collect_events) { collector.collect_events }

    before do
      allow(thread_api).to receive(:list).and_return(threads)
      allow(recorder).to receive(:push)
    end

    it 'produces stack events' do
      is_expected.to be_a_kind_of(Array)
      is_expected.to include(kind_of(Datadog::Profiling::Events::StackSample))
    end

    describe 'max_threads_sampled behavior' do
      context 'when number of threads to be sample is <= max_threads_sampled' do
        let(:threads) { Array.new(max_threads_sampled) { |n| instance_double(Thread, "Thread #{n}", alive?: true) } }

        it 'samples all threads' do
          sampled_threads = []
          expect(collector).to receive(:collect_thread_event).exactly(max_threads_sampled).times do |thread, *_|
            sampled_threads << thread
          end

          result = collect_events

          expect(result.size).to be max_threads_sampled
          expect(sampled_threads).to eq threads
        end
      end

      context 'when number of threads to be sample is > max_threads_sampled' do
        let(:threads) { Array.new(max_threads_sampled + 1) { |n| instance_double(Thread, "Thread #{n}", alive?: true) } }

        it 'samples exactly max_threads_sampled threads' do
          sampled_threads = []
          expect(collector).to receive(:collect_thread_event).exactly(max_threads_sampled).times do |thread, *_|
            sampled_threads << thread
          end

          result = collect_events

          expect(result.size).to be max_threads_sampled
          expect(threads).to include(*sampled_threads)
        end

        it 'eventually samples all threads' do
          sampled_threads = Set.new
          allow(collector).to receive(:collect_thread_event) { |thread, *_| sampled_threads << thread }

          begin
            Timeout.timeout(1) { collector.collect_events while sampled_threads.size != threads.size }
          rescue Timeout::Error
            raise 'Failed to eventually sample all threads in time given'
          end

          expect(threads).to contain_exactly(*sampled_threads.to_a)
        end
      end
    end

    context 'when the thread' do
      let(:thread) { instance_double(Thread, alive?: alive?) }
      let(:threads) { [thread] }
      let(:alive?) { tru