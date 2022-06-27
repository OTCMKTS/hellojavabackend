require 'datadog/profiling/spec_helper'

require 'datadog/profiling/http_transport'
require 'datadog/profiling'

require 'json'
require 'socket'
require 'webrick'

# Design note for this class's specs: from the Ruby code side, we're treating the `_native_` methods as an API
# between the Ruby code and the native methods, and thus in this class we have a bunch of tests to make sure the
# native methods are invoked correctly.
#
# We also have "integration" specs, where we exercise the Ruby code together with the C code and libdatadog to ensure
# that things come out of libdatadog as we expected.
RSpec.describe Datadog::Profiling::HttpTransport do
  before { skip_if_profiling_not_supported(self) }

  subject(:http_transport) do
    described_class.new(
      agent_settings: agent_settings,
      site: site,
      api_key: api_key,
      upload_timeout_seconds: upload_timeout_seconds,
    )
  end

  let(:agent_settings) do
    Datadog::Core::Configuration::AgentSettingsResolver::AgentSettings.new(
      adapter: adapter,
      uds_path: uds_path,
      ssl: ssl,
      hostname: hostname,
      port: port,
      deprecated_for_removal_transport_configuration_proc: deprecated_for_removal_transport_configuration_proc,
      timeout_seconds: nil,
    )
  end
  let(:adapter) { Datadog::Transport::Ext::HTTP::ADAPTER }
  let(:uds_path) { nil }
  let(:ssl) { false }
  let(:hostname) { '192.168.0.1' }
  let(:port) { '12345' }
  let(:deprecated_for_removal_transport_configuration_proc) { nil }
  let(:site) { nil }
  let(:api_key) { nil }
  let(:upload_timeout_seconds) { 10 }

  let(:flush) do
    Datadog::Profiling::Flush.new(
      start: start,
      finish: finish,
      pprof_file_name: pprof_file_name,
      pprof_data: pprof_data,
      code_provenance_file_name: code_provenance_file_name,
      code_provenance_data: code_provenance_data,
      tags_as_array: tags_as_array,
    )
  end
  let(:start_timestamp) { '2022-02-07T15:59:53.987654321Z' }
  let(:end_timestamp) { '2023-11-11T16:00:00.123456789Z' }
  let(:start)  { Time.iso8601(start_timestamp) }
  let(:finish) { Time.iso8601(end_timestamp) }
  let(:pprof_file_name) { 'the_pprof_file_name.pprof' }
  let(:pprof_data) { 'the_pprof_data' }
  let(:code_provenance_file_name) { 'the_code_provenance_file_name.json' }
  let(:code_provenance_data) { 'the_code_provenance_data' }
  let(:tags_as_array) { [%w[tag_a value_a], %w[tag_b value_b]] }

  describe '#initialize' do
    context 'when agent_settings are provided' do
      it 'picks the :agent working mode for the exporter' do
        expect(described_class)
          .to receive(:_native_validate_exporter)
          .with([:agent, 'http://192.168.0.1:12345/'])
          .and_return([:ok, nil])

        http_transport
      end

      context 'when ssl is enabled' do
        let(:ssl) { true }

        it 'picks the :agent working mode with https reporting' do
          expect(described_class)
            .to receive(:_native_validate_exporter)
            .with([:agent, 'https://192.168.0.1:12345/'])
            .and_return([:ok, nil])

          http_transport
        end
      end

      context 'when agent_settings requests a unix domain socket' do
        let(:adapter) { Datadog::Transport::Ext::UnixSocket::ADAPTER }
        let(:uds_pat