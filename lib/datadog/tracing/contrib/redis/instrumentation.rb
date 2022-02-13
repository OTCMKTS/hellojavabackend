require_relative '../patcher'
require_relative 'configuration/resolver'
require_relative 'ext'
require_relative 'quantize'
require_relative 'tags'

module Datadog
  module Tracing
    module Contrib
      module Redis
        # Instrumentation for Redis < 5
        module Instrumentation
          def self.included(base)
            base.prepend(InstanceMethods)
          end

          # InstanceMethods - implementing instrumentation
          module InstanceMethods
            def call(*args, &block)
              show_command_args = command_args?

              Tracing.trace(Contrib::Redis::Ext::SPAN_COMMAND) do |span|
                span.service = service_name
                span.span_type = Contrib::Redis::Ext::TYPE
                span.resource = get_command(args, show_command_args)
                Contrib::Redis::Tags.set_common_tags(self, span, show_command_args)

                super
              end
            end

            def call_pipeline(*args, &block)
              show_command_args = command_args?

              Tracing.trace(Contrib::Redis::Ext::SPAN_COMMAND) do |span|
                span.service = service_name
                span.span_type = Contrib::Redis::Ext::TYPE
               