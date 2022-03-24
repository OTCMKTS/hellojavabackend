require_relative '../core'
require_relative '../core/environment/identity'
require_relative '../core/utils'

require_relative 'event'
require_relative 'metadata/tagging'
require_relative 'sampling/ext'
require_relative 'span_operation'
require_relative 'trace_digest'
require_relative 'trace_segment'
require_relative 'utils'

module Datadog
  module Tracing
    # Represents the act of tracing a series of operations,
    # by generating and collecting span measurements.
    # When completed, it yields a trace.
    #
    # Supports synchronous code flow *only*. Usage across
    # multiple threads will result in incorrect relationships.
    # For async support, a {Datadog::Tracing::TraceOperation} should be employed
    # per execution context (e.g. Thread, etc.)
    #
    # @public_api
    class TraceOperation
      include Metadata::Tagging

      DEFAULT_MAX_LENGTH = 100_000

      attr_accessor \
        :agent_sample_rate,
        :hostname,
        :origin,
        :rate_limiter_rate,
        :rule_sample_rate,
        :sample_rate,
        :sampling_priority

      attr_reader \
        :active_span_count,
        :active_span,
        :id,
        :max_length,
        :parent_span_id

      attr_writer \
        :name,
        :resource,
        :sampled,
        :service

      def initialize(
        agent_sample_rate: nil,
        events: nil,
        hostname: nil,
        id: nil,
        max_length: DEFAULT_MAX_LENGTH,
        name: nil,
        origin: nil,
        parent_span_id: nil,
        rate_limiter_rate: nil,
        resource: nil,
        rule_sample_rate: nil,
        sample_rate: nil,
        sampled: nil,
        sampling_priority: nil,
        service: nil,
        tags: nil,
        metrics: nil
      )
        # Attributes
        @id = id || Tracing::Utils::TraceId.next_id
        @max_length = max_length || DEFAULT_MAX_LENGTH
        @parent_span_id = parent_span_id
        @sampled = sampled.nil? ? true : sampled

        # Tags
        @agent_sample_rate = agent_sample_rate
        @hostname = hostname
        @name = name
        @origin = origin
        @rate_limiter_rate = rate_limiter_rate
        @resource = resource
        @rule_sample_rate = rule_sample_rate
        @sample_rate = sample_rate
        @sampling_priority = sampling_priority
        @service = service

        # Generic tags
        set_tags(tags) if tags
        set_tags(metrics) if metrics

        # State
        @root_span = nil
        @active_span = nil
        @active_span_count = 0
        @events = events || Events.new
        @finished = false
        @spans = []
      end

      def full?
        @max_length > 0 && @active_span_count >= @max_length
      end

      def finished_span_count
        @spans.length
      end

      def finished?
        @finished == true
      end

      # Will this trace be flushed by the tracer transport?
      # This includes cases where the span is kept solely due to p