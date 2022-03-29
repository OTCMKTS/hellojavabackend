require 'json'

require_relative '../traces'
require_relative 'client'
require_relative 'response'
require_relative 'api/endpoint'
require_relative 'api/instance'

module Datadog
  module Transport
    module HTTP
      # HTTP transport behavior for traces
      module Traces
        # Response from HTTP transport for traces
        class Response
          include HTTP::Response
          include Datadog::Transport::Traces::Response

          def initialize(http_response, options = {})
            super(http_response)
            @service_rates = options.fetch(:service_rates, nil)
            @trace_count = options.fetch(:trace_count, 0)
          end
        end

        # Extensions for HTTP client
        module Client
          def send_traces_payload(request)
            send_request(request) do |api, env|
              api.send_traces(env)
            end
          end
        end

        module API
          # Extensions for HTTP API Spec
          module Spec
            attr_reader :traces

            def traces=(endpoint)
              @traces = endpoint
            end

            def send_traces(env, &block)
              raise NoTraceEndpointDefinedError, self if traces.nil?

              traces.call(env, &block)
            end

            def encoder
              traces.encoder
            end

            # Raised when traces sent but no traces endpoint is defined
            class NoTraceEndpointDefinedError < StandardError
              attr_reader :spec

              def initialize(spec)
                @spec = spec
              end

              def message
                'No trace endpoint is defined for API specification!'
              end
            end
          end

          # Extensions for HTTP API Instance
          module Instance
            def send_traces(env)
              raise TracesNotSupportedError, spec unless spec.is_a?(Traces::API::Spec)

              spec.sen