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

    i