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

  describe '#