require 'spec_helper'

require 'datadog/tracing/utils'
require 'datadog/opentracer'

RSpec.describe Datadog::OpenTracer::DistributedHeaders do
  subject(:headers) { described_class.new(carrier) }

  let(:carrier) { instance_double(Datadog::OpenTracer::Carrier) }

  describe '#valid?' do
    subject(:valid) { headers.valid? }

    before do
      allow(carrier).to receive(:[])
        .with('x-datadog-trace-id')
        .and_return(trace_id)

      allow(carrier).to receive(:[])
        .with('x-datadog-parent-id')
        .and_return(parent_id)
    end

    context 'when #trace_id is missing' do
      let(:trace_id) { nil }
      let(:parent_id) { (Datadog::Tracing::Utils::EXTERNAL_MAX_ID + 1).to_s }

      it { is_expected.to be false }
    end

    context 'when #parent_id is missing' do
      let(:trace_id) { (Datadog::Tracing::Utils::EXTERNAL_MAX_ID + 1).to_s }
      let(:parent_id) { nil }

      it { is_expected.to be false }
    end

    context 'when both #trace_id and #parent_id are present' do
      let(:trace_id) { (Datadog::Tracing::Utils::EXTERNAL_MAX_ID - 1).to_s }
      let(:parent_id) { (Datadog::Tracing::Utils::EXTERNAL_MAX_ID - 1).to_s }

      it { is_expected.to be true }
    end
  end

  describe '#trace_id' do
    subject(:trace_id) { headers.trace_id }

    before do
      allow(carrier).to receive(:[])
        .with('x-datadog-trace-id')
        .and_return(value)
    end

    context 'when the header is missing' do
      let(:value) { nil }
    end

    context 'when the header is present' do
      context 'but the value is out of range' do
        let(:value) { (Datadog::Tracing::Utils::EXTERNAL_MAX_ID + 1).to_s }

        it { is_expected.to be nil }
      en