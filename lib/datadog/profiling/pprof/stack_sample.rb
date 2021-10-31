require_relative '../ext'
require_relative '../events/stack'
require_relative 'builder'
require_relative 'converter'

module Datadog
  module Profiling
    module Pprof
      # Builds a profile from a StackSample
      #
      # NOTE: This class may appear stateless but is in fact stateful; a new instance should be created for every
      # encoded profile.
      class StackSample < Converter
        SAMPLE_TYPES = {
          cpu_time_ns: [
            Profiling::Ext::Pprof::VALUE_TYPE_CPU,
            Profiling::Ext::Pprof::VALUE_UNIT_NANOSECONDS
          ],
          wall_time_ns: [
            Profiling::Ext::Pprof::VALUE_TYPE_WALL,
            Profiling::Ext::Pprof::VALUE_UNIT_NANOSECONDS
          ]
        }.freeze

        def self.sample_value_types
          SAMPLE_TYPES
        end

        def initialize(*_)
          super

          @most_recent_trace_samples = {}
          @processed_unique_stacks = 0
          @processed_with_trace = 0
        end

        def add_events!(stack_samples)
          new_samples = build_samples(stack_samples)
          builder.samples.concat(new_samples)
        end

        def stack_sample_group_key(stack_sample)
          # We want to make sure we have the most recent sample for any trace.
          # (This is done here to save an iteration over al