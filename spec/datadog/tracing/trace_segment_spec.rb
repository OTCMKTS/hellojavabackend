require 'spec_helper'

require 'datadog/core/environment/identity'
require 'datadog/tracing/sampling/ext'
require 'datadog/tracing/span'
require 'datadog/tracing/trace_segment'
require 'datadog/tracing/utils'

RSpec.describe Datadog::Tracing::TraceSegment do
  let(:trace_id) { Datadog::Tracing::Utils::TraceId.next_id }
  let(:options) { {} }
  let(:spans) do
    Array.new(3) do |i|
      span = Datadog::Tracing::Span.new(
        'job.work',
        trace_id: trace_id,
        resource: 'generate_report',
        service: 'jobs-worker',
        type: 'worker'
      )

      span.set_tag('component', 'sidekiq')
      span.set_tag('job.id', i)
      span
    end
  end
  subject(:trace_segment) { described_class.new(spans, **options.merge(id: trace_id)) }

  describe '::new' do
    context 'by default' do
      it do
        is_expected.to have_attributes(
          agent_sample_rate: nil,
          hostname: nil,
          id: trace_id,
          lang: nil,
          name: nil,
          origin: nil,
          process_id: nil,
          rate_limiter_rate: nil,
          resource: nil,
          rule_sample_rate: nil,
          runtime_id: nil,
          sample_rate: nil,
          sampling_priority: nil,
          service: nil,
          spans: spans,
        )
      end

      it do
        expect(trace_segment.send(:meta)).to eq({})
      end

      it do
        expect(trace_segment.send(:metrics)).to eq({})
      end
    end

    context 'given arguments' do
      context ':agent_sample_rate' do
        let(:options) { { agent_sample_rate: agent_sample_rate } }
        let(:agent_sample_rate) { rand }

        it { is_expected.to have_attributes(agent_sample_rate: agent_sample_rate) }
      end

      context ':