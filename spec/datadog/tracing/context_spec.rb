require 'spec_helper'

require 'datadog/tracing/context'
require 'datadog/tracing/trace_operation'

RSpec.describe Datadog::Tracing::Context do
  subject(:context) { described_class.new(**options) }

  let(:options) { {} }

  describe '#initialize' do
    context 'with defaults' do
      it do
        is_expected.to have_attributes(
          active_trace: nil
        )
      end
    end

    context 'given' do
      context ':trace' do
        let(:options) { { trace: trace } }
        let(:trace) { instance_double(Datadog::Tracing::TraceOperation, finished?: finished?) }

        context 'that is finished' do
          let(:finished?) { true }

          it do
            is_expected.to have_attributes(
              active_trace: nil
            )
          end
        end

        context 'that isn\'t finished' do
          let(:finished?) { false }

          it do
            is_expected.to have_attributes(
              active_trace: trace
            )
          end
        end
      end
    end
  end

  describe '#activate!' do
    subject(:activate!) { context.activate!(trace) }

    context 'given a TraceOperation' do
      let(:trace) { instance_double(Datadog::Tracing::TraceOperation, finished?: finished?) }

      context 'that is finished' do
   