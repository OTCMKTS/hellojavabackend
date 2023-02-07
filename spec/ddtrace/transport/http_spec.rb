
require 'spec_helper'

require 'ddtrace/transport/http'
require 'uri'

RSpec.describe Datadog::Transport::HTTP do
  describe '.new' do
    context 'given a block' do
      subject(:new_http) { described_class.new(&block) }

      let(:block) { proc {} }

      let(:builder) { instance_double(Datadog::Transport::HTTP::Builder) }
      let(:transport) { instance_double(Datadog::Transport::Traces::Transport) }

      before do
        expect(Datadog::Transport::HTTP::Builder).to receive(:new) do |&blk|
          expect(blk).to be block
          builder
        end

        expect(builder).to receive(:to_transport)
          .and_return(transport)
      end

      it { is_expected.to be transport }
    end
  end

  describe '.default' do
    subject(:default) { described_class.default }
    let(:env_agent_settings) { described_class::DO_NOT_USE_ENVIRONMENT_AGENT_SETTINGS }

    # This test changes based on the environment tests are running. We have other
    # tests around each specific environment scenario, while this one specifically
    # ensures that we are matching the default environment settings.
    #
    # TODO: we should deprecate the use of DO_NOT_USE_ENVIRONMENT_AGENT_SETTINGS
    # and thus remove this test scenario.
    it 'returns a transport with default configuration' do
      is_expected.to be_a_kind_of(Datadog::Transport::Traces::Transport)
      expect(default.current_api_id).to eq(Datadog::Transport::HTTP::API::V4)

      expect(default.apis.keys).to eq(
        [
          Datadog::Transport::HTTP::API::V4,
          Datadog::Transport::HTTP::API::V3,
        ]
      )

      default.apis.each_value do |api|
        expect(api).to be_a_kind_of(Datadog::Transport::HTTP::API::Instance)
        expect(api.headers).to include(described_class.default_headers)

        case env_agent_settings.adapter
        when :net_http
          expect(api.adapter).to be_a_kind_of(Datadog::Transport::HTTP::Adapters::Net)
          expect(api.adapter.hostname).to eq(env_agent_settings.hostname)
          expect(api.adapter.port).to eq(env_agent_settings.port)
          expect(api.adapter.ssl).to be(env_agent_settings.ssl)
        when :unix