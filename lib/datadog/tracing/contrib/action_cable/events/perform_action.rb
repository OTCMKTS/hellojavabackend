require_relative '../../../metadata/ext'
require_relative '../../analytics'
require_relative '../event'

module Datadog
  module Tracing
    module Contrib
      module ActionCable
        module Events
          # Defines instrumentation for 'perform_action.action_cable' event.
          #
          # An action, triggered by a WebSockets client, invokes a method
          # in the server's channel instance.
          module PerformAction
            include ActionCable::RootContextEvent

            EVENT_NAME = 'perform_action.action_cable'.freeze

            module_function

            def event_name
              self::EVENT_NAME
            end

            def span_name
              Ext::SPAN_ACTION
            end

            def span_type
              # A request to perform_action comes from a WebSocket connection
              Tracing::Metadata::Ext::AppTypes::TYPE_WEB
            end

            def process(span, _event, _id, payload)
              channel_class = payload[:channel_class]
              action = payload[: