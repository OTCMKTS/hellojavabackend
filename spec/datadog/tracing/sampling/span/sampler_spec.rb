require 'datadog/tracing/sampling/span/matcher'
require 'datadog/tracing/sampling/span/rule'

require 'datadog/tracing/sampling/span/sampler'

RSpec.describe Datadog::Tracing::Sampling::Span::Sampler do
  subject(:sampler) { described_class.new(rules) }
  let(:rules) { [] }

  let(:trace_op) { Datadog::Tracing::TraceOperation.new }
  let(:span_op) { Datadog::Tracing::SpanOperation.new('name', service: 'service') }

  describe '#sample!' do
    subject(:sample!) { sampler.sample!(trace_op, span_op) }

    shared_examples 'does not modify trace' do
      it 'does not change span' do
        expect { sample! }.to_not(change { span_op.send(:build_span).to_hash })
      end

      it 'does not change sampling decision' do
        expect { sample! }.to_not(
          change do
            trace_op.get_tag(
              Datadog::Tracing::Metadata::Ext::Distributed::TAG_DECISION_MAKER
            )
          end
        )
      end
    end

    shared_examples 'set sampling decision' do
      it do
        sample!
        expect(span_op.get_metric('_dd.span_sampling.mechanism')).to_not be_nil
        expect(trace_op.get_tag('_dd.p.dm')).to eq('-8')
      end
    end

  