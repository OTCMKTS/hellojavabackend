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

      it 'aliases #span_type= to #type=' do
        span_type = 'foo'
        span_op.span_type = 'foo'
        expect(span_op.type).to eq(span_type)
      end

      it_behaves_like 'a root span operation'
    end

    context 'given an option' do
      shared_examples 'a string property' do |nillable: true|
        let(:options) { { property => value } }

        context 'set to a String' do
          let(:value) { 'test string' }
          it { is_expected.to have_attributes(property => value) }
        end

        context 'set to a non-UTF-8 String' do
          let(:value) { 'ascii'.encode(Encoding::ASCII) }
          it { is_expected.to have_attributes(property => value) }
          it { expect(span_op.public_send(property).encoding).to eq(Encoding::UTF_8) }
        end

        context 'invoking the public setter' do
          subject! { span_op.public_send("#{property}=", value) }

          context 'with a string' do
            let(:value) { 'test string' }
            it { expect(span_op).to have_attributes(property => value) }
          end

          context 'with a string that is not in UTF-8' do
            let(:value) { 'ascii'.encode(Encoding::ASCII) }
            it { expect(span_op).to have_attributes(property => value) }
            it { expect(span_op.public_send(property).encoding).to eq(Encoding::UTF_8) }
          end
        end

        if nillable
          context 'set to nil' do
            let(:value) { nil }
            # Allow property to be explicitly set to nil
            it { is_expected.to have_attributes(property => nil) }
          end
        else
          context 'set to nil' do
            let(:value) { nil }
            it { expect { subject }.to raise_error(ArgumentError) }
          end
        end
      end

      describe ':child_of' do
        let(:options) { { child_of: child_of } }

        context 'that is nil' do
          let(:child_of) { nil }
          it_behaves_like 'a root span operation'
        end

        context 'that is a SpanOperation' do
          include_context 'parent span operation'
          let(:child_of) { parent }

          context 'and no :service is given' do
            it_behaves_like 'a child span operation'

            it 'does not use the parent span service' do
              is_expected.to have_attributes(
                service: nil
              )
            end
          end

          context 'and :service is given' do
            let(:options) { { child_of: parent, service: service } }
            let(:service) { String.new }

            it_behaves_like 'a child span operation'

            it 'uses the :service option' do
              is_expected.to have_attributes(
                service: service
              )
            end
          end
        end
      end

      context ':on_error' do
        let(:options) { { on_error: block } }

        let(:block) { proc { raise error } }
        let(:error) { error_class.new('error message') }
        let(:error_class) { stub_const('TestError', Class.new(StandardError)) }

        context 'that is nil' do
          let(:on_error) { nil }

          context 'and #measure raises an error' do
            subject(:measure) { span_op.measure { raise error } }

            before { allow(span_op).to receive(:set_error) }

            it 'propagates the error' do
              expect { measure }.to raise_error(error)
              expect(span_op).to have_received(:set_error).with(error)
            end
          end
        end

        context 'that is a block' do
          let(:on_error) { block }

          it 'yields to the error block and raises the error' do
            expect do
              expect do |b|
                options[:on_error] = b.to_proc
                span_op.measure(&block)
              end.to yield_with_args(
                a_kind_of(described_class),
                error
              )
            end.to raise_error(error)

            # It should not set an error, as this overrides behavior.
            expect(span_op).to_not have_error
          end
        end

        context 'that is not a Proc' do
          let(:on_error) { 'not a proc' }

          it 'fallbacks to default error handler and log a debug message' do
            expect(Datadog.logger).to receive(:debug).at_least(:once)
            expect do
              span_op.measure(&block)
            end.to raise_error(error)
          end
        end
      end

      describe ':name' do
        it_beh