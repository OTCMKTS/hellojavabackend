require 'spec_helper'
require 'datadog/profiling/spec_helper'

require 'datadog/tracing'
require 'datadog/core/utils/time'
require 'datadog/profiling'

RSpec.describe 'profiling integration test' do
  before do
    skip_if_profiling_not_supported(self)

    raise "Profiling did not load: #{Datadog::Profiling.unsupported_reason}" unless Datadog::Profiling.supported?
  end

  let(:tracer) { instance_double(Datadog::Tracing::Tracer) }

  shared_context 'StackSample events' do
    # NOTE: Please do not convert stack_one or stack_two to let, because
    # we want the method names on the resulting stacks to be stack_one or
    # stack_two, not block in ... when showing up in the stack traces
    def stack_one
      @stack_one ||= Array(Thread.current.backtrace_locations)[1..3]
    en