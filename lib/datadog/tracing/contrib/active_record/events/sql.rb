require_relative '../../../../tracing'
require_relative '../../../metadata/ext'
require_relative '../event'
require_relative '../ext'
require_relative '../../analytics'
require_relative '../../utils/database'

module Datadog
  module Tracing
    module Contrib
      module ActiveRecord
        module Events
          # Defines instrumentation for sql.active_record event
          module SQL
            include ActiveRecord::Event

            EVENT_NAME = 'sql.active_record'.freeze
            PAYLOAD_CACHE = 'CACHE'.freeze

            module_function

            def event_name
              self::EVENT_NAME
            end

            def span_name
              Ext::SPAN_SQL
            end

            def process(span, event, _id, payload)
              config = Utils.connection_config(payload[:connection], payload[:connection_id])
              settings = Datadog.configuration.tracing[:active_record, config]
              adapter_name = Contrib::Utils::Database.normalize_vendor(config[:adapter])
              service_name = if settings.service_name != Contrib::Utils::Database::VENDOR_DEFAULT
                               settings.service_name
                             else
                               adapter_name
                             end

              span.name = "#{adapter_name}.query"
              span.service = service_name
              span.resource = payload.fetch(:sql)
              span.span_type = Tracing::Metadata::Ext::SQL::TYPE

              span.set_tag(Tracing::Metadata::Ext::TAG_COMPONENT, Ext::TAG_COMPONENT)
              span.set_tag(Tracing::Metadata::Ext::TAG_OPERATION, Ext::TAG_OPERATION_SQL)

              # Tag as an external peer service
              span.set_tag(Tracing::Metadata::Ext::TAG_PEER_SERVICE, span.service)
              # TODO: Populate hostname for JDBC connections
              span.set_tag(Tracing::Metadata::Ext::TAG_PEER_HOSTNAME, config[:host]) if config[:host]

              # Set analytics sample rate
              if Contrib::Analytics.enabled?(configuration[:analytics_enabled])
                Contrib::Analytics.set_sample_rate(span, configuration[:analytics_sample_rate])
              end

              # Find out if the SQL query has been cached in this request. This meta is really
          