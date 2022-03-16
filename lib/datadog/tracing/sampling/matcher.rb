module Datadog
  module Tracing
    module Sampling
      # Checks if a trace conforms to a matching criteria.
      # @abstract
      # @public_api
      class Matcher
        # Returns `true` if the trace should conforms to this rule, `false` otherwise
        #
        # @param [TraceOperation] trace
        # @return [Boolean]
        def match?(trace)
          raise NotImplementedError
        end
      end

      # A {Datadog::Sampling::Matcher} that supports matching a trace by
      # trace name and/or service name.
      # @public_api
      class SimpleMatcher < Matcher
        # Returns `true` for case equality (===) with any object
        MATCH_ALL = Class.new do
          # DEV: A class that implements `#===` is ~20% faster than
          # DEV: a `Proc` that always returns `true`.
          def ===(other)
            true
          end
        end.new

        attr_reader :name, :service

        # @param name [String,Regexp,Proc] Matcher for case equality (===) with