# frozen_string_literal: true

require_relative '../core/utils/safe_dup'
require_relative 'utils'

require_relative 'metadata/ext'
require_relative 'metadata'

module Datadog
  module Tracing
    # Represents a logical unit of work in the system. Each trace consists of one or more spans.
    # Each span consists of a start time and a duration. For example, a span can describe the time
    # spent on a distributed call on a separate machine, or the time spent in a small component
    # within a larger operation. Spans can be nested within each other, and in those instances
    # will have a parent-child relationship.
    # @public_api
    class Span
      include Metadata

      attr_accessor \
        :end_time,
        :id,
        :meta,
        :metrics,
        :name,
        :parent_id,
        :resource,
        :service,
        :type,
        :start_time,
        :status,
        :trace_id

      attr_writer \
        :duration

      # For backwards compatiblity
      # TODO: Deprecate and remove these.
      alias :span_id :id
      alias :span_type :type

      # Create a new span manually. Call the <tt>start()</tt> method to start the time
      # measurement and then <tt>stop()</tt> once the timing operation is over.
      #
      # * +service+: the service name for this span
      # * +resource+: the resource this span refers, or +name+ if it's missing.
      #     +nil+ can be used as a placeholder, when the resource value is not yet known at +#initialize+ time.
      # * +type+: the type of the span (such as +http+, +db+ and so on)
      # * +parent_id+: the identifier of the parent span
      # * +trace_id+: the identifier of the root span for this trace
      # * +service_entry+: whether it is a service entry span.
      # TODO: Remove span_type
      def initialize(
        name,
        duration: nil,
        end_time: nil,
        id: nil,
        meta: nil,
        metrics: nil,
        parent_id: 0,
        resource: name,
        service: nil,
        span_type: nil,
        start_time: nil,
        status: 0,
        type: span_type,
        trace_id: nil,
        service_entry: nil
      )
        @name = Core::Utils::SafeDup.frozen_or_dup(name)
        @service = Core::Utils::SafeDup.frozen_or_dup(service)
        @resource = Core::Utils::SafeDup.frozen_or_dup(resource)
        @type = Core::Utils::SafeDup.frozen_or_dup(type)

        @id = id || Tracing::Utils.next_id
        @parent_id = parent_id || 0
        @trace_id = trace_id || Tracing::Utils.next_id

        @meta = meta || {}
        @metrics = metrics || {}
        @status = status || 0

        # start_time and end_time track wall clock. In Ruby, wall clock
        # has less accuracy than monotonic clock, so if possible we look to only use wall clock
        # to measure duration when a time is supplied by the user, or if monotonic clock
        # is unsupported.
        @start_time = start_time
        @end_time = end_time

        # duration_start and duration_end track monotonic clock, and may remain nil in cases where it
        # is known that we have to use wall clock to measure duration.
        @duration = duration

        @service_entry = service_entry

        # Mark with the service entry span metric