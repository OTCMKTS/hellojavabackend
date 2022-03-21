module Datadog
  module Tracing
    module Sampling
      module Span
        # Applies Single Span Sampling rules to spans.
        # When matching the configured rules, a span is ensured to
        # be processed Datadog App. In other words, a single sampled span
        # will never be dropped by the tracer or Datadog agent.
        #
        # All spans in a trace are subject to the single sampling rules, if
        # any rules are configured.
        #
        # Single Span Sampling is distinct from trace-level sampling:
        # Single Span Sampling can ensure a span is kept, even if its
        # enclosing trace is rejected by trace-level sampling.
        #
        # This class only applies operations to spans that are part
        # of traces that was rejected by trace sampling.
        # A trace is rejected if either of the following conditions is true:
        # * The priority sampling for a trace is set to either {USER_REJECT} or {AUTO_REJECT}.
        # * The trace was rejected by internal sampling, thus never flushed.
        #
        # Single-sampled spans are tagged and the tracer ensures they will
        # reach the Datadog App, regardless of their enclosing trace sampling decision.
        #
        # Single Span Sampling does not inspect spans that are part of a trace
        # that has been accepted by trace-level sampling rules: all spans from such
        # trace are guaranteed to reach the Datadog App.
        class Sampler
          attr_reader :rules

          # Receives sampling rules to apply to individual spans.
          #
          # @param [Array<Datadog::Tracing::Sampling::Span::Rule>] rules list of rules to apply to spans
          def initialize(rules = [])
            @rules = rules
          end

          # Applies Single Span Sampling rules to the span 