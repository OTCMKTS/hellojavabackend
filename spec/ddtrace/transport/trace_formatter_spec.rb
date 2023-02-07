require 'spec_helper'

require 'datadog/core/environment/identity'
require 'datadog/core/runtime/ext'

require 'datadog/tracing/metadata/ext'
require 'datadog/tracing/sampling/ext'
require 'datadog/tracing/span'
require 'datadog/tracing/trace_segment'
require 'datadog/tracing/utils'
require 'ddtrace/transport/trace_formatter'

RSpec.describe Datadog::Transport::TraceFormatter do
  subject(:trace_formatter) { described_class.new(trace) }
  let(:trace_options) { { id: trace_id } }
  let(:trace_id) { Datadog::Tracing::Utils::TraceId.next_id }

  shared_context 'trace metadata' do
    let(:trace_tags) do
      nil
    end

    let(:trace_options) do
      {
        id: trace_id,
        resource: resource,
        agent_sample_rate: agent_sample_rate,
        hostname: hostname,
        lang: lang,
        origin: origin,
        process_id: process_id,
        rate_limiter_rate: rate_limiter_rate,
        rule_sample_rate: rule_sample_rate,
        runtime_id: runtime_id,
        sample_rate: sample_rate,
        sampling_priority: sampling_priority,
        tags: trace_tags
      }
    end

    let(:resource) { 'trace.resource' }
    let(:agent_sample_rate) { rand }
    let(:hostname) { 'trace.hostname' }
    let(:lang) { Datadog::Core::Environment::Identity.lang }
    let(:origin) { 'trace.origin' }
    let(:process_id) { 'trace.process_id' }
    let(:rate_limiter_rate) { rand }
    let(:rule_sample_rate) { rand }
    let(:runtime_id) { 'trace.runtime_id' }
    let(:sample_rate) { rand }
    let(:sampling_priority) { Datadog::Tracing::Sampling::Ext::Priority::USER_KEEP }
  end

  shared_context 'trace metadata with tags' do
    include_context 'trace metadata'

    let(:trace_tags) do
      {
        'foo' => 'bar',
        'baz' => 42,
        '_dd.p.dm' => '-1',
        '_dd.p.tid' => 'aaaaaaaaaaaaaaaa'
      }
    end
  end

  shared_context 'no root span' do
    let(:trace) { Datadog::Tracing::TraceSegment.new(spans, **trace_options) }
    let(:spans) { Array.new(3) { Datadog::Tracing::Span.new('my.job') } }
    let(:root_span) { spans.last }
  end

  shared_context 'missing root span' do
    let(:trace) do
      Datadog::Tracing::TraceSegment.new(
        spans,
        root_span_id: Datadog::Tracing::Utils.next_id,
        **trace_options
      )
    end
    let(:spans) { Array.new(3) { Datadog::Tracing::Span.new('my.job') } }
    let(:root_span) { spans.last }
  end

  shared_context 'available root span' do
    let(:trace) { Datadog::Tracing::TraceSegment.new(spans, root_span_id: root_span.id, **trace_options) }
    let(:spans) { Array.new(3) { Datadog::Tracing::Span.new('my.job') } }
    let(:root_span) { spans[1] }
  end

  describe '::new' do
    context 'given a TraceSegment' do
      shared_examples 'a formatter with root span' do
        it do
          is_expected.to have_attributes(
            trace: trace,
            root_span: root_span
          )
        end
      end

      context 'with no root span' do
        include_context 'no root span'
        it_behaves_like 'a formatter with root span'
      end

      context 'with missing root span' do
        include_context 'missing root span'
        it_behaves_like 'a formatter with root span'
      end

      context 'with a root span' do
        include_context 'available root span'
        it_behaves_like 'a formatter with root span'
      end
    end
  end

  describe '#format!' do
    subject(:format!) { trace_formatter.format! }

    context 'when initialized with a TraceSegment' do
      shared_examples 'root span with no tags' do
        it do
          format!
          expect(root_span).to have_metadata(
            Datadog::Tracing::Metadata::Ext::Sampling::TAG_AGENT_RATE => nil,
            Datadog::Tracing::Metadata::Ext::NET::TAG_HOSTNAME => nil,
            Datadog::Core::Runtime::Ext::TAG_LANG => nil,
            Datadog::Tracing::Metadata::Ext::Distributed::TAG_ORIGIN => nil,
            Datadog::Core::Runtime::Ext::TAG_PROCESS_ID => nil,
            Datadog::Tracing::Metadata::Ext::Sampling::TAG_RATE_LIMITER_RATE => nil,
            Datadog::Tracing::Metadata::Ext::Sampling::TAG_RULE_SAMPLE_RATE => nil,
            Datadog::Core::Runtime::Ext::TAG_ID => nil,
            Datadog::Tracing::Metadata::Ext::Sampling::TAG_SAMPLE_RATE => nil,
            Datadog::Tracing::Metadata::Ext::Distributed::TAG_SAMPLING_PRIORITY => nil
          )
        end
      end

      shared_examples 'root span with tags' do
        it do
          format!
          expect(root_span).to have_metadata(
            Datadog::Tracing::Metadata::Ext::Sampling::TAG_AGENT_RATE => agent_sample_rate,
            Datadog::Tracing::Metadata::Ext::NET::TAG_HOSTNAME => hostname,
            Datadog::Core::Runtime::Ext::TAG_