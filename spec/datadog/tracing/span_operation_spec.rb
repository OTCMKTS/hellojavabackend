require 'spec_helper'

require 'securerandom'
require 'time'

require 'datadog/core'
require 'datadog/core/logger'

require 'datadog/tracing/metadata/ext'
require 'datadog/tracing/span_operation'
require 'datadog/tracing/span'
require 'datadog/tracing/utils'

RSpec.describe Datadog::Tracing::SpanOperation do
  subject(:span_op) { described_class.new(name, **options) }
  let(:name) { 'my.operation' }
  let(:options) { {} }

  shared_examples 'a root span operation' do
    it do
      is_expected.to have_attributes(
        parent_id: 0
      )
    end
  end

  shared_examples 'a child span operation' do
    it 'associates to the parent' do
      expect(span_op).to have_attributes(
        parent_id: parent.span_id,
        trace_id: parent.trace_id
      )
    end
  end

  shared_context 'parent span operation' do
    let(:parent) { described_class.new('parent', service: parent_service) }
    let(:parent_service) { instance_double(String) }
  end

  shared_context 'callbacks' do
    let(:callback_spy) { spy('callback spy') }

    before do
      events = span_op.send(:events)

      # after_finish
      allow(callback_spy).to receive(:after_finish)
      events.after_finish.subscribe do |*args|
        callback_spy.after_finish(*args)
      end

      # after_stop
      allow(callback_spy).to receive(:after_stop)
      events.after_stop.subscribe do |*args|
        callback_spy.after_stop(*args)
      end

      # before_start
      allow(callback_spy).to receive(:before_start)
      events.before_start.subscribe do |*args|
        callback_spy.before_start(*args)
      end

      # on_error
      allow(callback_spy).to receive(:on_error)
      events.on_error.wrap_default do |*args|
        callback_spy.on_error(*args)
      end
    end
  end

  describe '::new' do
    context 'given only a name' do
      it 'has default attributes' do
        is_expected.to have_attributes(
          end_time: nil,
          id: kind_of(Integer),
          name: name,
          parent_id: 0,
          resource: name,
          service: nil,
          start_time: nil,
          status: 0,
          trace_id: kind_of(Integer),
          type: nil
        )
      end

      it 'has default behavior' do
        is_expected.to have_attributes(
          duration: nil,
          finished?: false,
          started?: false,
          stopped?: false
        )
      end

      it 'aliases #span_id' do
        expect(span_op.id).to eq(span_op.span_id)
      end

      it 'aliases #span_type' do
        expect(span_op.type).to eq(span_op.span_type)
      end