require 'uri'

require_relative '../../metadata/ext'
require_relative '../../propagation/http'
require_relative '../analytics'
require_relative 'ext'

module Datadog
  module Tracing
    module Contrib
      module RestClient
        # RestClient RequestPatch
        module RequestPatch
          def self.included(base)
            base.prepend(InstanceMethods)
          end

          # InstanceMethods - implementing instrumentation
          module InstanceMethods
            def execute(&block)
              uri = URI.parse(url)

              return super(&block) unless Tracing.enabled?

              datadog_trace_request(uri) do |_span, trace|
                Tracing::Propagation::HTTP.inject!(trace, processed_headers) if datadog_configuration[:distributed_tracing]

                super(&block)
              end
            end

            def datadog_tag_request(uri, span)
              span.resource = method.to_s.upcase

              span.set_tag(Tracing::Metadata::Ext::TAG_KIND, Tracing::Metadata::Ext::SpanKind::TAG_CLIENT)

              span.set_tag(Tracing::Metadata::Ext::TAG_COMPONENT, Ext::TAG_COMPONENT)
              span.set_tag(Tracing::Metadata::Ext::TAG_OPERATION, Ext::TAG_OPERATION_REQUEST)

              # Tag as an external peer service
              span.set_tag(Tracing::Metadata::Ext::TAG_PEER_SERVICE, span.service)
              span.set_tag(Tracing::Metadata::Ext::TAG_PEER_HOSTNAME, uri.host)

              # Set analytics sample rate
              Contrib::Analytics.set_sample_rate(span, analytics_sample_rate) if analytics_enabled?

              span.set_tag(Tracing::Metadata::Ext::HTTP::TAG_URL, uri.path)
              span.set_tag(Tracing::Metadata::Ext::H