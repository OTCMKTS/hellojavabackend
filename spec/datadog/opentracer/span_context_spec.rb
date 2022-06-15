require 'spec_helper'

require 'datadog/tracing/context'
require 'datadog/opentracer'

RSpec.describe Datadog::OpenTracer::SpanContext do
  describe '#initialize' do
    context 'given a Datadog::Context' do
      subject(:span_context) { described_class.new(datadog_context: datadog_context) }

      let(:datadog_context) { instance_double(Datadog::Tracing::Context) }

      it do
        is_expected.to have_attributes(
          datadog_context: datadog_context,
          baggage: {}
        )
      end

      context 'and baggage' do
        subject(:span_context) do
          described_class.new(
            datadog_context: datadog_context,
     