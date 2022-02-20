module Datadog
  module Tracing
    module Contrib
      module Shoryuken
        # Shoryuken integration constants
        # @public_api Changing resource names, tag names, or environment variables creates breaking changes.
        module Ext
          ENV_ENABLED = 'DD_TRACE_SHORYUKEN_ENABLED'.freeze
          ENV_ANALYTICS_ENABLED = 'DD_TRACE_SHORYUKEN_ANALYTICS_ENABLED'.freeze
          ENV_ANALYTICS_SAMPLE_RATE = 'DD_TRACE_SHORYUKEN_ANALYTICS_SAMPLE_RATE'.freeze
          SERVICE_NAME = 'shoryuken'.freeze
          SPAN_JOB = 'shoryuken.job'.freeze
          TAG_JOB_ID = 'shoryuken.id'.freeze
          TAG_JOB_QUEUE = 'shoryuke