require 'spec_helper'

require 'ddtrace/transport/traces'

RSpec.describe Datadog::Transport::Traces::EncodedParcel do
  subject(:parcel) { described_class.new(data, trace_count) }

  let(:data) { instance_double(Array) }
  let(:trace_count) { 123 }

  it { is_expected.to be_a_kind_of(Datadog::Transport::Parcel) }

  describe '#initialize' do
    it { is_expected.to have_attributes(data: data) }
  end

  describe '#count' do
    subject(:count) { parcel.count }

    let(:length) { double('length') }

    before { expect(data).to receive(:length).and_return(length) }

    it { is_expected.to be length }
  end

  describe '#trace_count' do
    subject { parcel.trace_count }

    it { is_expected.to eq(trace_count) }
  end
end

RSpec.describe Datadog::Transport::Traces::Request do
  subject(:request) { described_class.new(parcel) }

  let(:parcel) { double }

  it { is_expected.to be_a_kind_of(Datadog::Transport::Request) }

  describe '#initialize' do
    it do
      is_expected.to have_attributes(parcel: parcel)
    end
  end
end

RSpec.describe Datadog::Transport::Traces::Response do
  context 'when implemented by a class' do
    subject(:response) { response_class.new }

    let(:response_class) do
      stub_const('TestResponse', Class.new { include Datadog::Transport::Traces::Response })
    end

    describe '#service_rates' do
      it { is_expected.to respond_to(:service_rates) }
    end
  end
end

RSpec.describe Datadog::Transport::Traces::Chunker do
  let(:chunker) { described_class.new(encoder, max_size: max_size) }
  let(:encoder) { instance_double(Datadog::Core::Encoding::Encoder) }
  let(:trace_encoder) { Datadog::Transport::Traces::Encoder }
  let(:max_size) { 10 }

  describe '#encode_in_chunks' do
    subject(:encode_in_chunks) { chunker.encode_in_chunks(traces) }

    context 'with traces' do
      let(:traces) { get_test_traces(3) }

      before do
        allow(trace_encoder).to receive(:encode_trace).with(encoder, traces[0]).and_return('1')
        allow(trace_encoder).to receive(:encode_trace).with(encoder, traces[1]).and_return('22')
        allow(trace_encoder).to receive(:encode_trace).with(encoder, traces[2]).and_return('333')
        allow(encoder).to receive(:join) { |arr| arr.join(',') }
      end

      it do
        is_expected.to eq([['1,22,333', 3]])
      end

      context 'with batching required' do
        let(:max_size) { 3 }

        it do
          is_expected.to eq([['1,22', 2], ['333', 1]])
        end
      end

      context 'with individual traces too large' do
        include_context 'health metrics'

        let(:max_size) { 1 }

        before do
          Datadog.configuration.diagnostics.debug = true
          allow(Datadog.logger).to receive(:debug)
        end

        it 'drops all traces except the smallest' do
          is_expected.to eq([['1', 1]])
          expect(Datadog.logger).to have_lazy_debug_logged(/Payload too large/)
          expect(health_metrics).to have_received(:transport_trace_too_large).with(1).twice
        end
      end
    end

    context 'with a lazy enumerator' do
      let(:traces) { [].lazy }

      before do
        if PlatformHelpers.jruby? && PlatformHelpers.engine_version < Gem::Version.new('9.2.9.0')
          skip 'This runtime returns eager enumerators on Enumerator::Lazy methods calls'
        end
      end

      it 'does not force enumerator expansion' do
        expect(subject).to be_a(Enumerator::Lazy)
      end
    end
  end
end

RSpec.describe Datadog::Transport::Traces::Transport do
  subject(:transport) { described_class.new(apis, current_api_id) }

  shared_context 'APIs with fallbacks' do
    let(:current_api_id) { :v2 }
    let