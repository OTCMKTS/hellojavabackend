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

          def log_error!(type, error)
            Datadog.logger.warn("DATADOG DIAGNOSTIC - #{type}: #{error}")
          end

          # Are we logging the environment data?
          def log?
            startup_logs_enabled = Datadog.configuration.diagnostics.startup_logs.enabled
            if startup_logs_enabled.nil?
              !repl? # Suppress logs if we running in a REPL
            else
              startup_logs_enabled
            end
          end

          REPL_PROGRAM_NAMES = %w[irb pry].freeze

          def repl?
            REPL_PROGRAM_NAMES.include?($PROGRAM_NAME)
          end
        end
      end

      # Collects environment information for diagnostic logging
      class EnvironmentCollector
        # @return [String] current time in ISO8601 format
        def date
          DateTime.now.iso8601
        end

        # Best portable guess of OS information.
        # @return [String] platform string
        def os_name
          RbConfig::CONFIG['host'.freeze]
        end

        # @return [String] ddtrace version
        def version
          DDTrace::VERSION::STRING
        end

        # @return [String] "ruby"
        def lang
          Core::Environment::Ext::LANG
        end

        # Supported Ruby language version.
        # Will be distinct from VM version for non-MRI environments.
        # @return [String]
        def lang_version
          Core::Environment::Ext::LANG_VERSION
        end

        # @return [String] configured application environment
        def env
          Datadog.configuration.env
        end

        # @return [Boolean, nil]
        def enabled
          Datadog.configuration.tracing.enabled
        end

        # @return [String] configured application service name
        def service
          Datadog.configuration.service
        end

        # @return [String] configured application version
        def dd_version
          Datadog.configuration.version
        end

        # @return [String, nil] target agent URL for trace flushing
        def agent_url
          # Retrieve the effect agent URL, regardless of how it was configured
          transport = Tracing.send(:tracer).writer.transport

          # return `nil` with IO transport
          return unless transport.respond_to?(:client)

          adapter = transport.client.api.adapter
          adapter.url
        end

        # Error returned by Datadog agent during a tracer flush attempt
        # @return [String] concatenated list of transport errors
        def agent_error(transport_responses)
          error_responses = transport_responses.reject(&:ok?)

          return nil if error_responses.empty?

          error_responses.map(&:inspect).join(','.freeze)
        end

        # @return [Boolean, nil] debug mode enabled in configuration
        def debug
          !!Datadog.configuration.diagnostics.debug
        end

        # @return [Boolean, nil] analytics enabled in configuration
        def analytics_enabled
          !!Datadog.configuration.tracing.analytics.enabled
        end

        # @return [Numeric, nil] tracer sample rate configured
        def sample_rate
          sampler = Datadog.configuration.tracing.sampler
          return nil unless sampler

          sampler.sample_rate(nil) rescue nil
        end

        # DEV: We currently only support SimpleRule instances.
        # DEV: These are the most commonly used rules.
        # DEV: We should expand support for other rules in the future,
        # DEV: although it is tricky to serialize arbitrary rules.
        #
        # @return [Hash, nil] sample rules configured
        def sampling_rules
          sampler = Datadog.configuration.tracing.sampler
          return nil unless sampler.is_a?(Tracing::Sampling::PrioritySampler) &&
            sampler.priority_sampler.is_a?(Tracing::Sampling::RuleSampler)

          sampler.priority_sampler.rules.map do |rule|
            next unless rule.is_a?(Tracing::Sampling::SimpleRule)

            {
              name: rule.matcher.name,
              service: rule.matcher.service,
              sample_rate: rule.sampler.sample_rate(nil)
            }
          end.compact
        end

        # @return [Hash, nil] concatenated list of global tracer tags configured
        def tags
          tags = Datadog.configuration.tags
          return nil if tags.empty?

          hash_serializer(tags)
        end

        # @return 