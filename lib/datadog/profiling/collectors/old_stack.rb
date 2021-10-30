require_relative '../../core/utils/only_once'
require_relative '../../core/utils/time'
require_relative '../../core/worker'
require_relative '../../core/workers/polling'
require_relative '../backtrace_location'
require_relative '../events/stack'
require_relative '../native_extension'

module Datadog
  module Profiling
    module Collectors
      # Collects stack trace samples from Ruby threads for both CPU-time (if available) and wall-clock.
      # Runs on its own background thread.
      #
      # This class has the prefix "Old" because it will be deprecated by the new native CPU Profiler
      class OldStack < Core::Worker
        include Core::Workers::Polling

        DEFAULT_MAX_TIME_USAGE_PCT = 2.0
        MIN_INTERVAL = 0.01
        THREAD_LAST_CPU_TIME_KEY = :datadog_profiler_last_cpu_time
        THREAD_LAST_WALL_CLOCK_KEY = :datadog_profiler_last_wall_clock
        SYNTHETIC_STACK_IN_NATIVE_CODE = [BacktraceLocation.new('', 0, 'In native code').freeze].freeze

        # This default was picked based on the current sampling performance and on expected concurrency on an average
        # Ruby MRI application. Lowering this optimizes for latency (less impact each time we sample), and raising
        # optimizes for coverage (less chance to miss what a given thread is doing).
        DEFAULT_MAX_THREADS_SAMPLED = 16

        attr_reader \
          :recorder,
          :max_frames,
          :trace_identifiers_helper,
          :ignore_thread,
          :max_time_usage_pct,
          :thread_api,
          :cpu_time_provider

        def initialize(
          recorder,
          max_frames:,
          trace_identifiers_helper:, # Usually an instance of Profiling::TraceIdentifiers::Helper
          ignore_thread: nil,
          max_time_usage_pct: DEFAULT_MAX_TIME_USAGE_PCT,
          max_threads_sampled: DEFAULT_MAX_THREADS_SAMPLED,
          thread_api: Thread,
          cpu_time_provider: Profiling::NativeExtension,
          fork_policy: Core::Workers::Async::Thread::FORK_POLICY_RESTART, # Restart in forks by default
          interval: MIN_INTERVAL,
          enabled: true
        )
          @recorder = recorder
          @max_frames = max_frames
          @trace_identifiers_helper = trace_identifiers_helper
          @ignore_thread = ignore_thread
          @max_time_usage_pct = max_time_usage_pct
          @max_threads_sampled = max_threads_sampled
          @thread_api = thread_api
          # Only set the provider if it's able to work in the current Ruby/OS combo
          @cpu_time_provider = cpu_time_provider unless cpu_time_provider.cpu_time_ns_for(thread_api.current).nil?

          # Workers::Async::Thread settings
          self.fork_policy = fork_policy

          # Workers::IntervalLoop settings
          self.loop_base_interval = interval

          # Workers::Polling settings
          self.enabled = enabled

          # Cache this proc, since it's pretty expensive to keep recreating it
          @build_backtrace_location = method(:build_backtrace_location).to_proc
          # Cache this buffer, since it's pretty expensive to keep accessing it
          @stack_sample_event_recorder = recorder[Events::StackSample]
          # See below for details on why this is needed
          @needs_process_waiter_workaround = Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.7')
        end

        def start
          reset_cpu_time_tracking
          perform
        end

        def perform
          collect_and_wait
        end

        def collect_and_wait
          run_time = Core::Utils::Time.measure do
            collect_events
          end

          # Update wait time to throttle profiling
          self.loop_wait_time = compute_wait_time(run_time)
        end

        def collect_events
          events = []
          current_wall_time_ns = get_current_wall_time_timestamp_ns

          # Collect backtraces from each thread
          threads_to_sample.each do |thread|
            next unless thread.alive?
            next if ignore_thread.is_a?(Proc) && ignore_thread.call(thread)

            event = collect_thread_event(thread, current_wall_time_ns)
            events << event unless event.nil?
          end

          # Send events to recorder
          recorder.push(events) unless events.empty?

          events
        end

        def collect_thread_event(thread, current_wall_time_ns)
          locations = thread.backtrace_locations
          return if locations.nil?

          # Having empty locations means that the thread is alive, but we don't know what it's doing:
          #
          # 1. It can be starting up
          #    ```
          #    > Thread.new { sleep }.backtrace
          #    => [] # <-- note the thread hasn't actually started running sleep yet, we got there first
          #    ```
          # 2. It can be running native code
          #    ```
          #    > t = Process.detach(fork { sleep })
          #    => #<Process::Waiter:0x00007ffe7285f7a0 run>
          #    > t.backtrace
          #    => [] # <-- this can happen even minutes later, e.g. it's not a race as in 1.
          #    ```
          #    This effect has been observed in threads created by the Iodine web server and the ffi gem
          #
          # To give customers visibility into these threads, we replace the empty stack with one containing a
          # synthetic placeholder frame, so that these threads are properly represented in the UX.
          locations = SYNTHETIC_STACK_IN_NATIVE_CODE if locations.empty?

          # Get actual stack size then trim the stack
          stack_size = locations.length
          locations = locations[0..(max_frames - 1)]

          # Convert backtrace locations into structs
          locations = convert_backtrace_locations(locations)

          thread_id = thread.object_id
          root_span_id, span_id, trace_resource = trace_identifiers_helper.trace_identifiers_for(thread)
          cpu_time = get_cpu_time_interval!(thread)
          wall_time_interval_ns =
            get_elapsed_since_last_sample_and_set_value(thread, THREAD_LAST_WALL_CLOCK_KEY, current_wall_time_ns)

          Events::StackSample.new(
            nil,
            locations,
            stack_size,
            thread_id,
            root_span_id,
            span_id,
            trace_resource,
            cpu_time,
            wall_time_interval_ns
          )
        end

        def get_cpu_time_interval!(thread)
          return unless cpu_time_provider

          current_cpu_time_ns = cpu_time_provider.cpu_time_ns_for(thread)

          return unless current_cpu_time_ns

          get_elapsed_since_last_sample_and_set_value(thread, THREAD_LAST_CPU_TIME_KEY, current_cpu_time_ns)
        end

        def compute_wait_time(used_time)
          # We took used_time to get the last sample.
          #
          # What we're computing here is -- if used_time corresponds to max_time_usage_pct of the time we should
          # spend working, how much is (100% - max_time_usage_pct) of the time?
          #
          # For instance, if we took 10ms to sample, and max_time_usage_pct is 1%, then the other 99% is 990ms, which
          # means we need to sleep for 990ms to guarantee that we don't spend more than 1% of the time working.
          used_time_ns = used_time * 1e9
          interval = (used_time_ns / (max_time_usage_pct / 100.0)) - used_time_ns
          [interval / 1e9, MIN_INTERVAL].max
        end

        # Convert backtrace locations into structs
        # Re-use old backtrace location objects if they already exist in the buffer
        def convert_backtrace_locations(locations)
          locations.collect do |location|
            # Re-use existing BacktraceLocat