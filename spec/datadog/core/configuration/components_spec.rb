require 'spec_helper'
require 'datadog/profiling/spec_helper'

require 'logger'

require 'datadog/core/configuration/agent_settings_resolver'
require 'datadog/core/configuration/components'
require 'datadog/core/diagnostics/environment_logger'
require 'datadog/core/diagnostics/health'
require 'datadog/core/logger'
require 'datadog/core/telemetry/client'
require 'datadog/core/runtime/metrics'
require 'datadog/core/workers/runtime_metrics'
require 'datadog/profiling'
require 'datadog/profiling/collectors/code_provenance'
require 'datadog/profiling/collectors/old_stack'
require 'datadog/profiling/profiler'
require 'datadog/profiling/old_recorder'
require 'datadog/profiling/exporter'
require 'datadog/profiling/scheduler'
require 'datadog/profiling/tasks/setup'
require 'datadog/profiling/trace_identifiers/helper'
require 'datadog/statsd'
require 'datadog/tracing/flush'
require 'datadog/tracing/sampling/all_sampler'
require 'datadog/tracing/sampling/priority_sampler'
require 'datadog/tracing/sampling/rate_by_service_sampler'
require 'datadog/tracing/sampling/rule_sampler'
require 'datadog/tracing/sync_writer'
require 'datadog/tracing/tracer'
require 'datadog/tracing/writer'
require 'ddtrace/transport/http/adapters/net'

RSpec.describe Datadog::Core::Configuration::Components do
  subject(:components) { described_class.new(settings) }

  let(:settings) { Datadog::Core::Configuration::Settings.new }
  let(:agent_settings) { Datadog::Core::Configuration::AgentSettingsResolver.call(settings, logger: nil) }

  let(:profiler_setup_task) { Datadog::Profiling.supported? ? instance_double(Datadog::Profiling::Tasks::Setup) : nil }

  before do
    # Ensure the real task never gets run (so it doesn't apply our thread patches and other extensions to our test env)
    if Datadog::Profiling.supported?
      allow(Datadog::Profiling::Tasks::Setup).to receive(:new).and_retu