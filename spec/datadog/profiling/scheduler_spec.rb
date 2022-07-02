require 'spec_helper'

require 'datadog/profiling/http_transport'
require 'datadog/profiling/exporter'
require 'datadog/profiling/scheduler'

RSpec.describe Datadog::Profiling::Scheduler do
  subject(:scheduler) { described_class.new(exporter: exporter, transport: transport, **options) }

  let(:exporter) { instance_double(Datadog::Profiling::Exporter) }
  let(:transport) { i