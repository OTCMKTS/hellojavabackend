require_relative '../../metadata/ext'
require_relative 'ext'
require_relative '../analytics'

module Datadog
  module Tracing
    module Contrib
      module ActionCable
        module Instrumentation
          # When a new WebSocket is open, we receive a Rack request resource name "GET -1".
          # This module overrides the current Rack resource name to provide a meaningful name.
          module ActionCableConnection
            def on_open
              Tracing.trace(Ext::SPAN_ON_OPEN) do |span, trace|
                begin
                  span.resource = "#{self.class}#on_open"
                  span.span_type = Tracing::Metadata::Ext::AppTypes::TYPE_WEB

                  span.set_tag(Ext::TAG_ACTION, 'on_open')
                  span.set_tag(Ext::TAG_CONNECTION, self.class.to_s)

                  span.set_tag(Tracing::Metadata::Ext::TAG_COMPONENT, Ext::TAG_COMPONENT)
                  span.set_tag(Tracing::Metadata::Ext::TAG_OPERATION, E