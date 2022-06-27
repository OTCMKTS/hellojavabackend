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
        let(:uds_path) { '/var/run/datadog/apm.socket' }

        it 'picks the :agent working mode with unix domain stocket reporting' do
          expect(described_class)
            .to receive(:_native_validate_exporter)
            .with([:agent, 'unix:///var/run/datadog/apm.socket'])
            .and_return([:ok, nil])

          http_transport
        end
      end

      context 'when agent_settings includes a deprecated_for_removal_transport_configuration_proc' do
        let(:deprecated_for_removal_transport_configuration_proc) { instance_double(Proc, 'Configuration proc') }

        it 'logs a warning message' do
          expect(Datadog.logger).to receive(:warn)

          http_transport
        end

        it 'picks working mode from the agent_settings object' do
          allow(Datadog.logger).to receive(:warn)

          expect(described_class)
            .to receive(:_native_validate_exporter)
            .with([:agent, 'http://192.168.0.1:12345/'])
            .and_return([:ok, nil])

          http_transport
        end
      end

      context 'when agent_settings requests an unsupported transport' do
        let(:adapter) { :test }

        it do
          expect { http_transport }.to raise_error(ArgumentError, /Unsupported transport/)
        end
      end
    end

    context 'when additionally site and api_key are provided' do
      let(:site) { 'test.datadoghq.com' }
      let(:api_key) { SecureRandom.uuid }

      it 'ignores them and picks the :agent working mode using the agent_settings' do
        expect(described_class)
          .to receive(:_native_validate_exporter)
          .with([:agent, 'http://192.168.0.1:12345/'])
          .and_return([:ok, nil])

        http_transport
      end

      context 'when agentless mode is allowed' do
        around do |example|
          ClimateControl.modify('DD_PROFILING_AGENTLESS' => 'true') do
            example.run
          end
        end

        it 'picks the :agentless working mode with the given site and api key' do
          expect(described_class)
            .to receive(:_native_validate_exporter)
            .with([:agentless, site, api_key])
            .and_return([:ok, nil])

          http_transport
        end
      end
    end

    context 'when an invalid configuration is provided' do
      let(:hostname) { 'this:is:not:a:valid:hostname!!!!' }

      it do
        expect { http_transport }.to raise_error(ArgumentError, /Failed to initialize transport/)
      end
    end
  end

  describe '#export' do
    subject(:export) { http_transport.export(flush) }

    it 'calls the native export method with the data from the flush' do
      # Manually converted from the lets above :)
      upload_timeout_milliseconds = 10_000
      start_timespec_seconds = 1644249593
      start_timespec_nanoseconds = 987654321
      finish_timespec_seconds = 1699718400
      finish_timespec_nanoseconds = 123456789

      expect(described_class).to receive(:_native_do_export).with(
        kind_of(Array), # exporter_configuration
        upload_timeout_milliseconds,
        start_timespec_seconds,
        start_timespec_nanoseconds,
        finish_timespec_seconds,
        finish_timespec_nanoseconds,
        pprof_file_name,
        pprof_data,
        code_provenance_file_name,
        code_provenance_data,
        tags_as_array
      ).and_return([:ok, 200])

      export
    end

    context 'when successful' do
      before do
        expect(described_class).to receive(:_native_do_export).and_return([:ok, 200])
      end

      it 'logs a debug message' do
        expect(Datadog.logger).to receive(:debug).with('Successfully reported profiling data')

        export
      end

      it { is_expected.to be true }
    end

    context 'when failed' do
      before do
        expect(described_class).to receive(:_native_do_export).and_return([:ok, 500])
        allow(Datadog.logger).to receive(:error)
      end

      it 'logs an error message' do
        expect(Datadog.logger).to receive(:error)

        export
      end

      it { is_expected.to be false }
    end
  end

  context 'integration testing' do
    shared_context 'HTTP server' do
      let(:server) do
        WEBrick::HTTPServer.new(
          Port: port,
          Logger: log,
          AccessLog: access_log,
          StartCallback: -> { init_signal.push(1) }
        )
      end
      let(:hostname) { '127.0.0.1' }
      let(:port) { 6006 }
  