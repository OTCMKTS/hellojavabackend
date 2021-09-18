require 'date'
require 'json'
require 'rbconfig'

module Datadog
  module Core
    module Diagnostics
      # A holistic collection of the environment in which ddtrace is running.
      # This logger should allow for easy reporting by users to Datadog support.
      #
      module EnvironmentLogger
        class << self
          # Outputs environment information to {Datadog.logger}.
          # Executes only once for the lifetime of the program.
          def log!(transport_responses)
            return if (defined?(@executed) && @executed) || !log?

            @executed = true

            data = EnvironmentCollector.new.collect!(transport_responses)
            data.reject! { |_, v| v.nil? } # Remove empty values from hash output

            log_environment!(data.to_json)
            log_error!('Agent Error'.freeze, data[:agent_error]) if data[:agent_error]
          rescue => e
            Datadog.logger.warn("Failed to collect environment information: #{e} Location: #{Array(e.backtrace).first}")
          end

          private

          def log_environment!(line)
            Datadog.logger.info("DATADOG CONFIGURATION - #{line}")
          end

  