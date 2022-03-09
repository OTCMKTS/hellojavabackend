require_relative '../core'
require_relative 'utils'
require_relative 'metadata/ext'

module Datadog
  module Tracing
    # Contains behavior for managing correlations with tracing
    # e.g. Retrieve a correlation to the current trace for logging, etc.
    module Correlation
      # Represents current trace state with key identifiers
      # @public_api
      class Identifier
        LOG_ATTR_ENV = 'dd.env'.freeze
        LOG_ATTR_SERVICE = 'dd.service'.freeze
        LOG_ATTR_SPAN_ID = 'dd.span_id'.freeze
        LOG_ATTR_TRACE_ID = 'dd.trace_id'.freeze
        LOG_ATTR_VERSION = 'dd.version'.freeze

        attr_reader \
          :env,
          :service,
          :span_id,
          :span_name,
          :span_resource,
          :span_service,
          :span_type,
          :trace_id,
          :trace_name,
          :trace_resource,
          :trace_service,
          :version

        # @!visibility private
        def initialize(
          env: nil,
          service: nil,
          span_id: nil,
          span_name: nil,
          span_resource: nil,
          span_service: nil,
          span_type: nil,
          trace_id: nil,
          trace_name: nil,
          trace_resource: nil,
          trace_service: nil,
          version: nil
        )
          # Dup and freeze strings so they aren't modified by reference.
          @env = Core::Utils::SafeDup.frozen_or_dup(env || Datadog.configuration.env).freeze
          @service = Core::Utils::SafeDup.frozen_or_dup(service || Datadog.configuration.service).freeze
          @span_id = span_id || 0
          @span_name = Core::Utils::SafeDup.frozen_or_dup(span_name).freeze
          @span_resource = Core::Utils::SafeDup.frozen_or_dup(span_res