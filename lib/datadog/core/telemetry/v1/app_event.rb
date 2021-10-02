module Datadog
  module Core
    module Telemetry
      module V1
        # Describes payload for telemetry V1 API app-integrations-change event
        class AppEvent
          attr_reader \
            :additional_payload,
            :configuration,
            :dependencies,
            :integrations

          # @param additional_payload [Array<Telemetry::V1::Configuration>] List of Additional payload to track (any key
          #   value not mentioned and doesn't fit under a metric)
          # @param configuration [Array<Telemetry::V1::Configuration>] List of Tracer related configuration data
          # @param dependencies [Array<Telemetry::V1::Dependency>] List of all loaded modules requested by the app
 