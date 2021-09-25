# frozen_string_literal: true

require 'etc'

require_relative '../configuration/agent_settings_resolver'
require_relative '../environment/ext'
require_relative '../environment/platform'
require_relative 'v1/application'
require_relative 'v1/dependency'
require_relative 'v1/host'
require_relative 'v1/integration'
require_relative 'v1/product'
require_relative '../../../ddtrace/transport/ext'

module Datadog
  module Core
    module Telemetry
      # Module defining methods for collecting metadata for telemetry
      module Collector
        include Datadog::Core::Configuration

        # Forms a hash of configuration key value pairs to be sent in the additional payload
        def additional_payload
          additional_payload_variables
        end

        # Forms a telemetry application object
        def application
          Telemetry::V1::Application.new(
            env: env,
            language_name: Datadog::Core::Environment::Ext::LANG,
            language_version: Datadog::Core::Environment::Ext::LANG_VERSION,
            products: products,
            runtime_name: Datadog::Core::Environment::Ext::RUBY_ENGINE,
            runtime_version: Datadog::Core::Environment::Ext::ENGINE_VERSION,
            service_name: service_name,
            service_version: service_version,
            tracer_version: library_version
          )
        end

        # Forms a hash of standard key value pairs to be sent in the app-started event configuration
        def configurations
          configurations = {
            DD_AGENT_HOST: Datadog.configuration.agent.host,
            DD_AGENT_TRANSPORT: agent_transport,
            DD_TRACE_SAMPLE_RATE: format_configuration_value(Datadog.configuration.tracing.sampling.default_rate),
          }
          compact_hash(configurations)
        end

        # Forms a telemetry app-started dependencies object
        def dependencies
          Gem.loaded_specs.collect do |name, loaded_gem|
            Datadog::Core::Telemetry::V1::Dependency.new(
              name: name, version: loaded_gem.version.to_s, hash: loaded_gem.hash.to_s
            )
          end
        end

        # Forms a telemetry host object
        def host
          Telemetry::V1::Host.new(
            container_id: Core::Environment::Container.container_id,
            hostname: Core::Environment::Platform.hostname,
            kernel_name: Core::Environment::Platform.kernel_name,
            kernel_release: Core::Environment::Platform.kernel_release,
            kernel_version: Core::En