require_relative '../analytics'
require_relative 'ext'
require_relative 'configuration/settings'

module Datadog
  module Tracing
    module Contrib
      module GRPC
        # :nodoc:
        module DatadogInterceptor
          # :nodoc:
          class Base < ::GRPC::Interceptor
            def initialize(options = {})
              super
              return unless block_given?

              # Set custom configuration on the interceptor if block is given
              pin_adapter = PinAdapter.new
              yield(pin_adapter)
              Datadog.configure_onto(self, **pin_adapter.options)
            end

            def request_response(**keywords, &block)
              trace(keywords, &block)
            end

            def client_streamer(**keywords, &block)
              trace(keywords, &block)
            end

            def server_streamer(**keywords, &block)
              trace(keywords, &block)
            end

            def bidi_streamer(**keywords, &block)
              trace(keywords, &block)
            end

            private

            def datadog_configuration
              Datadog.configuration.tracing[:grpc]
            end

            def service_name
              Datadog.configuration_for(self, :service_name) || datadog_