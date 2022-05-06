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

      it_behaves_like 'default test span operation tags'
      it { expect(block_spy).to have_received(:call).with(span_op) }
      it { is_expected.to be(block_result) }
    end

    context 'when not given a block' do
      subject(:trace) { described_class.trace(span_name, options) }
      let(:span_op) { Datadog::Tracing::SpanOperation.new(span_name) }

      before do
        allow(Datadog::Tracing)
          .to receive(:trace)
          .with(
            span_name,
            { span_type: Datadog::CI::Ext::AppTypes::TYPE_TEST }
          )
          .and_return(span_op)

        allow(Datadog::Tracing::Contrib::Analytics).to receive(:set_measured)

        trace
      end

      it_behaves_like 'default test span operation tags'
      it { is_expected.to be(span_op) }
    end
  end

  describe '::set_tags!' do
    subject(:set_tags!) { described_class.set_tags!(trace_op, span_op, tags) }
    let(:span_op) { Datadog::Tracing::SpanOperation.new(span_name) }
    let(:tags) { {} }

    before do
      allow(Datadog::Tracing::Contrib::Analytics).to receive(:set_measured)
    end

    it_behaves_like 'default test span operation tags' do
      before { set_tags! }
    end

    context 'when trace operation is given' do
      before { set_tags! }

      it do
        expect(trace_op)
          .to have_received(:origin=)
          .with(Datadog::CI::Ext::Test::CONTEXT_ORIGIN)
      end
    end

    context 'when :framework is given' do
      let(:tags) { { framework: framework } }
      let(:framework) { 'framework' }

      before { set_tags! }

      it do
        expect(span_op.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK))
          .to eq(framework)
      end
    end

    context 'when :framework_version is given' do
      let(:tags) { { framework_version: framework_version } }
      let(:framework_version) { 'framework_version' }

      before { set_tags! }

      it do
        expect(span_op.get_tag(Datadog::CI::Ext::Test::TAG_FRAMEWORK_VERSION))
          .to eq(framework_version)
      end
    end

    context 'when :test_name is given' do
      let(:tags) { { test_name: test_name } }
      let(:test_name) { 'test name' }

      before { set_tags! }

      it do
        expect(span_op.get_tag(Datadog::CI::Ext::Test::TAG_NAME))
          .to eq(test_name)
      end
    end

    context 'when :test_suite is given' do
      let(:tags) { { test_suite: test_suite } }
      let(:test_suite) { 'test suite' }

      before { set_tags! }

      it do
        expect(span_op.get_tag(Datadog::CI::Ext::Test::TAG_SUITE))
          .to eq(test_suite)
      end
    end

    context 'when :test_type is given' do
      let(:tags) { { test_type: test_type } }
      let(:test_type) { 'test type' }

      before { set_tags! }

      it do
        expect(span_op.get_tag(Datadog::CI::Ext::Test::TAG_TYPE))
          .to eq(test_type)
      end
    end

    context 'with environment runtime information' do
      context 'for the architecture platform' do
        subject(:tag) do
          set_tags!
          span_op.get_tag(Datadog::CI::Ext::Test::TAG_OS_ARCHITECTURE)
        end

        it { is_expected.to eq('x86_64').or eq('i686').or eq('aarch64').or start_with('arm') }
      end

      context 'for the OS platform' do
        subject(:tag) do
          set_tags!
          span_op.get_tag(Datadog::CI::Ext::Test::TAG_OS_PLATFORM)
        end

        context 'with Linux', if: PlatformHelpers.linux? do
          it { is_expected.to start_with('linux') }
        end

        context 'with Mac OS', if: PlatformHelpers.mac? do
          it { is_expected.to start_with('darwin') }
        end

        it 'returns a valid string' do
          is_expected.to be_a(String)
        end
      end

      context 'for the runtime name' do
        subject(:tag) do
          set_tags!
          span_op.get_tag(Datadog::CI::Ext::Test::TAG_RUNTIME_NAME)
        end

        context 'with MRI', if: PlatformHelpers.mri? do
          it { is_expected.to eq('ruby') }
        end

        context 'with JRuby', if: PlatformHelpers.jruby? do
          it { is_expected.to eq('jruby') }
        end

        context 'with TruffleRuby', if: PlatformHelpers.truffleruby? do
          it { is_expected.to eq('truffleruby') }
        end

        it 'returns a valid string' do
          is_expected.to be_a(String)
        end
      end

      context 'for the runtim