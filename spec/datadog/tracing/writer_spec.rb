require 'spec_helper'

require 'json'

require 'datadog/core'
require 'datadog/core/diagnostics/environment_logger'
require 'datadog/tracing/runtime/metrics'
require 'datadog/tracing/trace_segment'
require 'datadog/tracing/writer'
require 'ddtrace/transport/http'
require 'ddtrace/transport/http/traces'
require 'ddtrace/transport/response'
require 'ddtrace/transport/statistics'
require 'ddtrace/transport/traces'

RSpec.describe Datadog::Tracing::Writer do
  include HttpHelpers

  describe 'instance' do
    subject(:writer) { described_class.new(options) }

    let(:options) { { transport: transport } }
    let(:transport) { instance_double(Datadog::Transport::Traces::Transport) }

    describe 'behavior' do
      describe '#initialize' do
        let(:options) { {} }

        context 'and default transport options' do
          it do
            expect(Datadog::Transport::HTTP).to receive(:default) do |**options|
              expect(options).to be_empty
            end

            writer
          end
        end

        context 'and custom transport options' do
          let(:options) { super().merge(transport_options: { api_version: api_version }) }
          let(:api_version) { double('API version') }

          it do
            expect(Datadog::Transport::HTTP).to receive(:default) do |**options|
              expect(options).to include(api_version: api_version)
            end

            writer
          end
        end

        context 'with agent_settings' do
          let(:agent_settings) { double('AgentSettings') }

          let(:options) { { agent_settings: agent_settings } }

     