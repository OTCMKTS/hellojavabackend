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
          @needs_process_waiter_workarou