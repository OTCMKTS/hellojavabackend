module Datadog
  module Profiling
    # Stores stack samples in a native libdatadog data structure and expose Ruby-level serialization APIs
    # Note that `record_sample` is only accessible from native code.
    # Methods prefixed with _native_ are implemented in `stack_recorder.c`
    class StackRecorder
      def initialize(cpu_time_enabled:, alloc_samples_enabled:)
        # This mutex works in addition to th