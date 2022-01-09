require_relative '../../ext'
require_relative '../../event'

module Datadog
  module Tracing
    module Contrib
      module Kafka
        module Events
          module ProduceOperation
            # Defines instrumentation for send_messages.producer.kafka event
            module SendMessages
              include Kafka::Event

              EVENT_NAME = 'send_messages.producer.kafka'.freeze

              def self.process(span, _event, _id, payload)
                super

                span.set_tag(Ext::TAG_MESSAGE_COUNT, payload[:message_count]) if payload.key?(:message_count)
                span.set_tag(Ext::TAG_SENT_MESSAGE_COUNT, payload[:sent_m