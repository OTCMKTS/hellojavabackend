# frozen_string_literal: true

module Datadog
  module Tracing
    module Distributed
      module Headers
        # DEV-2.0: This module only exists for backwards compatibility with the public API. It should be removed.
        # @deprecated use [Datadog::Tracing::Distributed::Ext]
        # @public_api
        module Ext
          HTTP_HEADER_TRACE_ID = 'x-datadog-trace-id'
          HTTP_HEADER_PARENT_ID = 'x-datadog-parent-id'
          HTTP_HEADER_SAMPLING_PRIORITY = 'x-datadog-sampling-priority'
          HTTP_HEADER_ORIGIN = 'x-datadog-origin'
          # Distributed trace-level tags
          HTTP_HEADER_TAGS = 'x-datadog-tags'

          # B3 k