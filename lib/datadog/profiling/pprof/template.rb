require_relative 'payload'
require_relative 'message_set'
require_relative 'builder'

require_relative '../events/stack'
require_relative 'stack_sample'

module Datadog
  module Profiling
    module Pprof
      # Converts a collection of profiling events into a Perftools::Profiles::Profile
      class Template
        DEFAULT_MAPPINGS = {
          Events::StackSample => Pprof::StackSample
        }.freeze

        attr_reader \
          :builder,
          :converters,
          :sample_type_mappings

        def self.for_event_classes(event_classe