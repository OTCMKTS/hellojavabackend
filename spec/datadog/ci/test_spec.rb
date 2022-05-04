require 'datadog/ci/spec_helper'

require 'datadog/ci/test'
require 'datadog/tracing'
require 'datadog/tracing/trace_operation'
require 'datadog/tracing/span_operation'
require 'datadog/tracing/contrib/analytics'

RSpec.describe Datadog::CI::Test do
  let(:trace_op) { instance_double(Datadog::Tracing::TraceOperation) }
  let(:span_name) { 'span name' }

  before do
    allow(Datadog::Tracing).to receive(:active_trace).and_return(trace_op)
    allow(trace_op).to receive(:origin=)
  end

  shared_examples_for 'default test span operation tags' do
    it do
      expect(Datadog::Tracing::Contrib::Analytics)
        .to have_received(:set_measured)
        .with(span_op)
    end

    it do
      expect(span_op.get_tag(Datadog::CI::Ext::Test::TAG_SPAN_KIND))
        .to eq(Datadog::CI::Ext::AppTypes::TYPE_TEST)
    end

    it do
      Datadog::CI::Ext::Environment.tags(ENV).each do |key, value|
        expect(span_op.get_tag(key))
          .to eq(value)
      end
    end

    it do
      expect(trace_op)
        .to have_received(:origin=)
        .with(Datadog::CI::Ext::Test::CONTEXT_ORIGIN)
    end
  end

  describe '::trace' do
    let(:options) { {} }

    context 'when given a block' do
      subject(:trace) { described_class.trace(span_name, options, &block) }
      let(:span_op) { Datadog::Tracing::SpanOperation.new(span_name) }
      let(:block) { proc { |s| block_spy.call(s) } }
      let(:block_result) { double('result') }
      let(:block_spy) { spy('block') }

      before do
        allow(block_spy).to receive(:call).and_return(block_result)

        allow(Datadog::Tracing)
          .to receive(:trace) do |trace_span_name, trace_span_options, &trace_block|
            expect(trace_span_name).to be(span_name)
            expect(trace_span_options).to eq({ span_type: Datadog::CI::Ext::AppTypes::TYPE_TEST })
            trace_block.call(span_op, trace_op)
          end

        allow(Datadog::Tracing::Contrib::Analytics).to receive(:set_measured)

        trace
      end

   