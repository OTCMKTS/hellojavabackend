module Datadog
  module Profiling
    module Tasks
      # Wraps command with Datadog tracing
      class Exec
        attr_reader