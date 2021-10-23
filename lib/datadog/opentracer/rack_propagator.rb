require_relative '../tracing/context'
require_relative '../tracing/propagation/http'
require_relative '../tracing/trace_operation'
require_relative 'propagator'

module Datadog
  module OpenTracer
    # OpenTracing propagator for Datadog::OpenTracer::Tracer
    module RackPropagator
      extend Propagator

      BAGGAGE_PREFIX = 'ot-baggage-'.freeze
      BAGGAGE_PREFIX_FORMATTED = 'HTTP_OT_BAGGAGE_'.freeze

      class << self
        # Inject a SpanContext into the given carri