# frozen_string_literal: true

module Datadog
  module OpenTelemetry
    module SDK
      # Compatibility wrapper to allow Datadog propagators to fulfill the
      # OpenTelemetry propagator API.
      class Propagator
        def initialize(datadog_propagator)
          @datadog_propagator = datadog_propagator
        end

        def inject(
          carrier, context: ::OpenTelemetry::Context.current,
          setter: ::OpenTelemetry::Context::Propagation.text_map_setter
        )
          unless setter