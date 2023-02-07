require 'spec_helper'

require 'datadog/core/environment/identity'
require 'datadog/core/runtime/ext'

require 'datadog/tracing/metadata/ext'
require 'datadog/tracing/sampling/ext'
require 'datadog/tracing/span'
require 'datadog/tracing/trace_segment'
require 'datadog/tracing/utils'
require 'ddtrace/transport/trace_formatter'

RSpec.describe Datadog::Transport::TraceFormatter do
  subject(:trace_formatter) { described_class.new(trace) }
  let(:trace_options) { { id: trace_id } }
  let(:trace_id) { Datadog::Tracing::Utils::Trace