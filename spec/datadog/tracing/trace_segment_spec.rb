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

      context ':hostname' do
        let(:options) { { hostname: hostname } }
        let(:hostname) { 'my.host' }

        it { is_expected.to have_attributes(hostname: be(hostname)) }
      end

      context ':lang' do
        let(:options) { { lang: lang } }
        let(:lang) { 'ruby' }

        it { is_expected.to have_attributes(lang: be(lang)) }
      end

      context ':name' do
        let(:options) { { name: name } }
        let(:name) { 'job.work' }

        it { is_expected.to have_attributes(name: be_a_copy_of(name)) }
      end

      context ':origin' do
        let(:options) { { origin: origin } }
        let(:origin) { 'synthetics' }

        it { is_expected.to have_attributes(origin: be_a_copy_of(origin)) }
      end

      context ':process_id' do
        let(:options) { { process_id: process_id } }
        let(:process_id) { Datadog::Core::Environment::Identity.pid }

        it { is_expected.to have_attributes(process_id: process_id) }
      end

      context ':rate_limiter_rate' do
        let(:options) { { rate_limiter_rate: rate_limiter_rate } }
        let(:rate_limiter_rate) { rand }

        it { is_expected.to have_attributes(rate_limiter_rate: rate_limiter_rate) }
      end

      context ':resource' do
        let(:options) { { resource: resource } }
        let(:resource) { 'generate_report' }

        it { is_expected.to have_attributes(resource: be_a_copy_of(resource)) }
      end

      context ':rule_sample_rate' do
        let(:options) { { rule_sample_rate: rule_sample_rate } }
        let(:rule_sample_rate) { rand }

        it { is_expected.to have_attributes(rule_sample_rate: rule_sample_rate) }
      end

      context ':runtime_id' do
        let(:options) { { runtime_id: runtime_id } }
        let(:runtime_id) { Datadog::Core::Environment::Identity.id }

        it { is_expected.to have_attributes(runtime_id: runtime_id) }
      end

      context ':sample_rate' do
        let(:options) { { sample_rate: sample_rate } }
        let(:sample_rate) { rand }

        it { is_expected.to have_attributes(sample_rate: sample_rate) }
      end

      context ':sampling_priority' do
        let(:options) { { sampling_priority: sampling_priority } }
        let(:sampling_priority) { Datadog::Tracing::Sampling::Ext::Priority::USER_KEEP }

        it { is_expected.to have_attributes(sampling_priority: sampling_priority) }
      end

      context ':service' do
        let(:options) { { service: service } }
        let(:service) { 'job-worker' }

        it { is_expected.to have_attributes(service: be_a_copy_of(service)) }
      end

      context ':tags' do
        let(:options) { { tags: tags } }
        let(:tags) { { 'foo' => 'bar' } }

        it { expect(trace_segment.send(:meta)).to eq({ 'foo' => 'bar' }) }
      end

      context ':metrics' do
        let(:options) { { metrics: metrics } }
        let(:metrics) { { 'foo' => 42.0 } }

        it { expect(trace_segment.send(:metrics)).to eq({ 'foo' => 42.0 }) }
      end
    end

    context 'given tags' do
      context ':agent_sample_rate' do
        let(:options) { { metrics: { Datadog::Tracing::Metadata::Ext::Sampling::TAG_AGENT_RATE => agent_sample_rate } } }
        let(:agent_sample_rate) { rand }

        it { is_expected.to have_attributes(agent_sample_rate: agent_sample_rate) }
      end

      context ':hostname' do
        let(:options) { { tags: { Datadog::Tracing::Metadata::Ext::NET::TAG_HOSTNAME => hostname } } }
        let(:hostname) { 'my.host' }

        it { is_expected.to have_attributes(hostname: be(hostname)) }
      end

      context ':lang' do
        let(:options) { { tags: { Datadog::Core::Runtime::Ext::TAG_LANG => lang } } }
        let(:lang) { 'ruby' }

        it { is_expected.to have_attributes(lang: be(lang)) }
      end

      context ':name' do
        let(:options) { { tags: { Datadog::Tracing::TraceSegment::TAG_NAME => name } } }
        let(:name) { 'job.work' }

        it { is_expected.to have_attributes(name: be_a_copy_of(name)) }
      end

      context ':origin' do
        let(:options) { { tags: { Datadog::Tracing::Metadata::Ext::Distributed::TAG_ORIGIN => origin } } }
        let(:origin) { 'synthetics' }

        it { is_expected.to have_attributes(origin: be_a_copy_of(origin)) }
      end

      context ':process_id' do
        let(:options) { { tags: { Datadog::Core::Runtime::Ext::TAG_PROCESS_ID => process_id } } }
        let(:process_id) { Datadog::Core::Environment::Ide