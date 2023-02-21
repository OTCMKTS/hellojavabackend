require 'support/metric_helpers'
require 'ddtrace'
require 'datadog/tracing/diagnostics/ext'

module HealthMetricHelpers
  include RSpec::Mocks::ArgumentMatchers

  METRICS = {
    api_errors: { type: :count, name: Datadog::Tracing::Diagnostics::Ext::Health::Metrics::METRIC_API_ERRORS },
    api_requests: { type: :count, name: Datadog::Tracing::Diagnostics::Ext::Health::Metrics::METRIC_API_REQUESTS },
    api_responses: { type: :count, name: Datadog::Tracing::Diagnostics::Ext::Health::Metrics::METRIC_API_RESPONSES },
    error_context_overflow: {
      type: :count, name: Datadog::Tracing::Diagnostics::Ext::Health::Metrics::METRIC_ERROR_CONTEXT_OVERFLOW
    },
    error_instrumentation_pat