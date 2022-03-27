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
      # This includes cases where the span is kept solely due to priority sampling.
      #
      # This is not the ultimate Datadog App sampling decision. Downstream systems
      # can decide to reject this trace, especially for cases where priority
      # sampling is set to AUTO_KEEP.
      #
      # @return [Boolean]
      def sampled?
        @sampled == true || priority_sampled?
      end

      # Has the priority sampling chosen to keep this span?
      # @return [Boolean]
      def priority_sampled?
        !@sampling_priority.nil? && @sampling_priority > 0
      end

      def keep!
        self.sampled = true
        self.sampling_priority = Sampling::Ext::Priority::USER_KEEP
        set_tag(Tracing::Metadata::Ext::Distributed::TAG_DECISION_MAKER, Tracing::Sampling::Ext::Decision::MANUAL)
      end

      def reject!
        self.sampled = false
        self.sampling_priority = Sampling::Ext::Priority::USER_REJECT
        set_tag(Tracing::Metadata::Ext::Distributed::TAG_DECISION_MAKER, Tracing::Sampling::Ext::Decision::MANUAL)
      end

      def name
        @name || (root_span && root_span.name)
      end

      def resource
        @resource || (root_span && root_span.resource)
      end

      # Returns true if the resource has been explicitly set
      #
      # @return [Boolean]
      def resource_override?
        !@resource.nil?
      end

      def service
        @service || (root_span && root_span.service)
      end

      def measure(
        op_name,
        events: nil,
        on_error: nil,
        resource: nil,
        service: nil,
        start_time: nil,
        tags: nil,
        type: nil,
        &block
      )
        # Don't allow more span measurements if the
        # trace is already completed. Prevents multiple
        # root spans with parent_span_id = 0.
        return yield(SpanOperation.new(op_name), TraceOperation.new) if finished? || full?

        # Create new span
        span_op = build_span(
          op_name,
          events: events,
          on_error: on_error,
          resource: resource,
          service: service,
          start_time: start_time,
          tags: tags,
          type: type
        )

        # Start span measurement
        span_op.measure { |s| yield(s, self) }
      end

      def build_span(
        op_name,
        events: nil,
        on_error: nil,
        resource: nil,
        service: nil,
        start_time: nil,
        tags: nil,
        type: nil
      )
        begin
          # Resolve span options:
          # Parent, service name, etc.
          # Add default options
          trace_id = @id
          parent = @active_span

          # Use active span's span ID if available. Otherwise, the parent span ID.
          # Necessary when this trace continues from another, e.g. distributed trace.
          parent_id = parent ? parent.id : @parent_span_id || 0

          # Build events
          events ||= SpanOperation::Events.new

          # Before start: activate the span, publish events.
          events.before_start.subscribe do |span_op|
            start_span(span_op)
          end

          # After finish: deactivate the span, record, publish events.
          events.after_finish.subscribe do |span, span_op|
            finish_span(span, span_op, parent)
          end

          # Build a new span operation
          SpanOperation.new(
            op_name,
            events: events,
            on_error: on_error,
            parent_id: parent_id,
            resource: resource || op_name,
            service: service,
            start_time: start_time,
            tags: tags,
            trace_id: trace_id,
            type: type
          )
        rescue StandardError => e
          Datadog.logger.debug { "Failed to build new span: #{e}" }

          # Return dummy span
          SpanOperation.new(op_name)
        end
      end

      # Returns a {TraceSegment} with all finished spans that can be flushed
      # at invocation time. All other **finished** spans are discarded.
      #
      # @yield [spans] spans that will be returned as part of the trace segment returned
      # @return [TraceSegment]
      def flush!
        finished = finished?

        # Copy out completed spans
        spans = @spans.dup
        @spans = []

        spans = yield(spans) if block_given?

        # Use them to build a trace
        build_trace(spans, !finished)
      end

      # Returns a set of trace headers used for continuing traces.
      # Used for propagation across execution contexts.
      # Data should reflect the active s