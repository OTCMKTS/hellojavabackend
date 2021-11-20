require_relative '../../../../tracing'
require_relative '../../../metadata/ext'

require_relative '../ext'
require_relative '../utils'
require_relative '../../rack/middlewares'
require_relative '../../analytics'

module Datadog
  module Tracing
    module Contrib
      module ActionPack
        module ActionController
          # Instrumentation for ActionController components
          module Instrumentation
            module_function

            def start_processing(payload)
              return unless Tracing.enabled?

              # trace the execution
              service = Datadog.configuration.tracing[:action_pack][:service_name]
              type = Tracing::Metadata::Ext::HTTP::TYPE_INBOUND
              span = Tracing.trace(
                Ext::SPAN_ACTION_CONTROLLER,
                service: service,
                span_type: type,
                resource: "#{payload.fetch(:controller)}##{payload.fetch(:action)}",
              )
              trace = Tracing.active_trace

              # attach the current span to the tracing context
              tracing_context = payload.fetch(:tracing_context)
              tracing_context[:dd_request_trace] = trace
              tracing_context[:dd_request_span] = span

              # We want the route to show up as the trace's resource
              trace.resource = span.resource

              span.set_tag(Tracing::Metadata::Ext::TAG_COMPONENT, Ext::TAG_COMPONENT)
              span.set_tag(Tracing::Metadata::Ext::TAG_OPERATION, Ext::TAG_OPERATION_CONTROLLER)
            rescue StandardError => e
              Datadog.logger.error(e.message)
            end

            def finish_processing(payload)
              return unless Tracing.enabled?

              # retrieve the tracing context and the latest active span
              tracing_context = payload.fetch(:tracing_context)
              trace = tracing_context[:dd_request_trace]
              span = tracing_context[:dd_request_span]
              return unless span && !span.finished?

              begin
                # We repeat this in both start and at finish because the resource may have changed during the request
                trace.resource = span.resource

                # Set analytics sample rate
                Utils.set_analytics_sample_rate(span)

                # Measure service stats
                Contrib::Analytics.set_measured(span)

                span.set_tag(Ext::TAG_ROUTE_ACTION, payload.fetch(:action))
                span.set_tag(Ext::TAG_ROUTE_CONTROLLER, payload.fetch(:controller))

                exception = payload[:exception_object]
                if exception.nil?
                  # [christian] in some cases :status is not defined,
                  # rather than firing an error, simply acknowledge we don't know it.
            