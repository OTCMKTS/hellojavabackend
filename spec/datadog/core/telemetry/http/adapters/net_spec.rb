require 'spec_helper'

require 'datadog/core/telemetry/http/adapters/net'

RSpec.describe Datadog::Core::Telemetry::Http::Adapters::Net do
  subject(:adapter) { described_class.new(hostname: hostname, port: port, **options) }

  let(:hostname) { double('hostname') }
  let(:port) { double('port') }
  let(:timeout) { double('timeout') }
  let(:options) { { timeout: timeout } }

  shared_context 'HTTP connection stub' do
    let(:http_connection) { instance_double(::Net::HTTP) }

    before do
      allow(::Net::HTTP).to receive(:new)
        .with(
          adapter.hostname,
          adapter.port,
        ).and_return(http_connection)

      allow(http_connection).to receive(:open_timeout=).with(adapter.timeout)
      allow(http_connection).to receive(:read_timeout=).with(adapter.timeout)
      allow(http_connection).to receive(:use_ssl=).with(adapter.ssl)

      allow(http_connection).to receive(:start).and_yield(http_connection)
    end
  end

  shared_context 'HTTP Env' do
    let(:env) do
      instance_double(
        Datadog::Core::Telemetry::Http::Env,
        path: path,
        body: body,
        headers: headers,
      )
    end

    let(:path) { '/foo' }
    let(:body) { '{}' }
    let(:headers) { {} }
  end

  describe '#initialize' do
    context 'given no options' do
      let(:options) { {} }

      it do
        is_expected.to have_attributes(
          hostname: hostname,
          port: port,
          timeout: Datadog::Core::Telemetry::Http::Adapters::Net::DEFAULT_TIMEOUT,
          ssl: true
        )
      end
    end

    context 'given a :timeout option' do
      let(:options) { { timeout: timeout } }
      let(:timeout) { double('timeout') }

      it { is_expected.to have_attributes(timeout: timeout) }
    end

    context 'given a :ssl option' do
      let(:options) { { ssl: ssl } }

      context 'with nil' do
        let(:ssl) { nil }

        it { is_expected.to have_attributes(ssl: true) }
      end

      context 'with false' do
        let(:ssl) { false }

        it { is_expected.to have_attributes(ssl: false) }
      end
    end
  end

  describe '#open' do
    include_context 'HTTP connection stub'

    it 'opens and yields a Net::HTTP connection' do
      expect { |b| adapter.open(&b) }.to yield_with_args(http_connection)
    end
  end

  describe '#post' do
    include_context 'HTTP connection stub'
    include_context 'HTTP Env'

    subject(:post) { adapter.post(env) }

    let(:http_response) { double('http_response') }

    context 'when request goes through' do
      before { expect(http_connection).to receive(:request).and_return(http_response) }

      it 'produces a response' do
        is_expected.to be_a_kind_of(described_class::Response)
        expect(post.http_response).to be(http_response)
      end
    end

    context 'when e