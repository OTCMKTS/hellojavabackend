module Datadog
  module Tracing
    # Trace digest that represents the important parts of an active trace.
    # Used to propagate context and continue traces across execution boundaries.
    # @public_api
    class TraceDigest
      # @!attribute [r] span_id
      #   Datadog id for the currently active span.
      #   @return [Integer]
      # @!attribute [r] span_name
      #   The operation name of the currently 