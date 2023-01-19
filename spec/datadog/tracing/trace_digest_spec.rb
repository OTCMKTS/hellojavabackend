
require 'spec_helper'

require 'datadog/core/environment/identity'

require 'datadog/tracing/sampling/ext'
require 'datadog/tracing/trace_digest'
require 'datadog/tracing/utils'

RSpec.describe Datadog::Tracing::TraceDigest do
  subject(:trace_digest) { described_class.new(**options) }
  let(:options) { {} }

  describe '::new' do
    context 'by default' do
      it do
        is_expected.to have_attributes(
          span_id: nil,
          span_name: nil,
          span_resource: nil,
          span_service: nil,
          span_type: nil,
          trace_distributed_tags: nil,
          trace_hostname: nil,
          trace_id: nil,
          trace_name: nil,
          trace_origin: nil,
          trace_process_id: nil,
          trace_resource: nil,
          trace_runtime_id: nil,
          trace_sampling_priority: nil,
          trace_service: nil,
          trace_distributed_id: nil,
          trace_flags: nil,
          trace_state: nil,
          trace_state_unknown_fields: nil
        )
      end

      it { is_expected.to be_frozen }
    end

    context 'given' do
      context ':span_id' do
        let(:options) { { span_id: span_id } }
        let(:span_id) { Datadog::Tracing::Utils.next_id }

        it { is_expected.to have_attributes(span_id: span_id) }
      end

      context ':span_name' do
        let(:options) { { span_name: span_name } }
        let(:span_name) { 'job.work' }

        it { is_expected.to have_attributes(span_name: be_a_frozen_copy_of(span_name)) }
      end

      context ':span_resource' do
        let(:options) { { span_resource: span_resource } }
        let(:span_resource) { 'generate_report' }

        it { is_expected.to have_attributes(span_resource: be_a_frozen_copy_of(span_resource)) }
      end

      context ':span_service' do
        let(:options) { { span_service: span_service } }
        let(:span_service) { 'job-worker' }

        it { is_expected.to have_attributes(span_service: be_a_frozen_copy_of(span_service)) }
      end

      context ':span_type' do
        let(:options) { { span_type: span_type } }
        let(:span_type) { 'worker' }

        it { is_expected.to have_attributes(span_type: be_a_frozen_copy_of(span_type)) }
      end

      context ':trace_distributed_tags' do
        let(:options) { { trace_distributed_tags: trace_distributed_tags } }
        let(:trace_distributed_tags) { { tag: 'value' } }

        it { is_expected.to have_attributes(trace_distributed_tags: be_a_frozen_copy_of(trace_distributed_tags)) }
      end

      context ':trace_hostname' do
        let(:options) { { trace_hostname: trace_hostname } }
        let(:trace_hostname) { 'my.host' }

        it { is_expected.to have_attributes(trace_hostname: be_a_frozen_copy_of(trace_hostname)) }
      end

      context ':trace_id' do
        let(:options) { { trace_id: trace_id } }
        let(:trace_id) { Datadog::Tracing::Utils.next_id }

        it { is_expected.to have_attributes(trace_id: trace_id) }
      end

      context ':trace_name' do
        let(:options) { { trace_name: trace_name } }
        let(:trace_name) { 'job.work' }

        it { is_expected.to have_attributes(trace_name: be_a_frozen_copy_of(trace_name)) }
      end

      context ':trace_origin' do
        let(:options) { { trace_origin: trace_origin } }
        let(:trace_origin) { 'synthetics' }

        it { is_expected.to have_attributes(trace_origin: be_a_frozen_copy_of(trace_origin)) }
      end

      context ':trace_process_id' do
        let(:options) { { trace_process_id: trace_process_id } }
        let(:trace_process_id) { Datadog::Core::Environment::Identity.pid }

        it { is_expected.to have_attributes(trace_process_id: trace_process_id) }
      end

      context ':trace_resource' do
        let(:options) { { trace_resource: trace_resource } }
        let(:trace_resource) { 'generate_report' }
