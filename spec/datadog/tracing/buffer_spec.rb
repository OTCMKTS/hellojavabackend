require 'spec_helper'

require 'benchmark'
require 'concurrent'

require 'datadog/core'
require 'datadog/tracing/buffer'

RSpec.describe Datadog::Tracing::TraceBuffer do
  subject(:buffer_class) { described_class }

  context 'with CRuby' do
    before { skip unless PlatformHelpers.mri? }

    it { is_expected.to eq Datadog::Tracing::CRubyTraceBuffer }
  end

  context 'with JRuby' do
    before { skip unless PlatformHelpers.jruby? }

    it { is_expected.to eq Datadog::Tracing::ThreadSafeTraceBuffer }
  end
end

RSpec.shared_examples 'thread-safe buffer' do
  subject(:buffer) { described_class.new(max_size) }

  let(:max_size) { 0 }
  let(:items) { defined?(super) ? super() : Array.new(items_count) { double('item') } }
  let(:items_count) { 10 }

  describe '#push' do
    subject(:push) { threads.each(&:join) }

    let(:output) { buffer.pop }
    let(:wait_for_threads) { threads.each { |t| raise 'Thread wait timeout' unless t.join(5000) } }
    let(:max_size) { 500 }
    let(:thread_count) { 100 }
    let(:threads) do
      buffer
      items

      Array.new(thread_count) do |_i|
        Thread.new do
          sleep(rand / 1000.0)
          buffer.push(items)
        end
      end
    end

    it 'does not have collisions' do
      push
      expect(output).to_not be nil
      expect(output).to match_array(Array.new(thread_count) { items })
    end

    context 'with items exceeding maximum size' do
      let(:max_size) { 100 }
      let(:thread_count) { 100 }
      let(:barrier) { Concurrent::CyclicBarrier.new(thread_count) }
      let(:threads) do
        buffer
        barrier
        items

        Array.new(thread_count) do |_i|
          Thread.new do
            barrier.wait
            1000.times { buffer.push(items) }
          end
        end
      end

      it 'does not exceed expected maximum size' do
        push
        expect(output).to have_at_most(max_size).items
      end

      context 'with #pop operations' do
        let(:barrier) { Concurrent::CyclicBarrier.new(thread_count + 1) }

        it 'executes without error' do
          threads

          barrier.wait
          1000.times do
            buffer.pop

            # Yield control to threads to increase contention.
            # Otherwise we might run #pop a few times in succession,
            # which doesn't help us stress test this case.
            Thread.pass
          end

          push
        end
      end
    end
  end

  describe '#concat' do
    subject(:concat) { wait_for_threads }
    let(:output) { buffer.pop }
    let(:wait_for_threads) { threads.each { |t| raise 'Thread wait timeout' unless t.join(5000) } }
    let(:bulk_items) { Array.new(10, items) }
    let(:max_size) { 5000 }
    let(:thread_count) { 100 }
    let(:threads) do
      buffer
      bulk_items

      Array.new(thread_count) do |_i|
        Thread.new do
          sleep(rand / 1000.0)
          buffer.concat(bulk_items)
        end
      end
    end

    it 'does not have collisions' do
      concat
      expect(output).to_not be nil
      expect(output).to match_array(thread_count.times.flat_map { bulk_items })
    end

    context 'with items exceeding maximum size' do
      let(:max_size) { 100 }
      let(:thread_count) { 100 }
      let(:items_count) { 10 }
      let(:barrier) { Concurrent::CyclicBarrier.new(thread_count) }
      let(:threads) do
        buffer
        barrier
        items

        Array.new(thread_count) do |_i|
          Thread.new do
            barrier.wait
            500.times { buffer.concat(items) }
          end
        end
      end

      it 'does not exceed expected maximum size' do
        concat
        expect(output).to have_at_most(max_size).items
      end

      context 'with #pop operations' do
        let(:barrier) { Concurrent::CyclicBarrier.new(thread_count + 1) }

        it 'executes without error' do
          threads

          barrier.wait
          1000.times do
            buffer.pop

            # Yield control to threads to increase contention.
            # Otherwise we might run #pop a few times in succession,
            # which doesn't help us stress test this case.
            Thread.pass
          end

          concat
        end
      end
    end
  end

  describe '#pop' do
    subject(:pop) { buffer.pop }

    let(:traces) { get_test_traces(2) }

    before do
      traces.each { |t| buffer.push(t) }
    end

    it do
      expect(pop.length).to eq(traces.length)
      expect(pop).to include(*traces)
      expect(buffer.empty?).to be true
    end
  end
end

RSpec.shared_examples 'trace buffer' do
  include_context 'health metrics'

  subject(:buffer) { described_class.new(max_size) }

  let(:max_size) { 0 }

  def measure_traces_size(traces)
    traces.inject(ObjectSpaceHelper.estimate_bytesize(traces)) do |sum, trace|
      sum + measure_trace_size(trace)
    end
  end

  def measure_trace_size(trace)
    trace.inject(ObjectSpaceHelper.estimate_bytesize(trace)) do |sum, span|
      sum + ObjectSpaceHelper.estimate_bytesize(span)
    end
  end

  describe '#initialize' do
    it { is_expected.to be_a_kind_of(described_class) }
  end

  describe '#push' do
    subject(:push) { items.each { |t| buffer.push(t) } }

    let(:items_count) { max_size + 1 }
    let(:pop) { buffer.pop }

    context 'given a max size' do
      let(:max_size) { 3 }

      it 'records health metrics' do
        push

        accepted_spans = items.inject(0) { |sum, t| sum + t.length }

        # A trace will be dropped at random, except the trace
        # that triggered the overflow.
        dropped_traces = items.reject { |t| pop.i