
require 'spec_helper'

require 'datadog/profiling/old_recorder'
require 'datadog/profiling/event'

RSpec.describe Datadog::Profiling::OldRecorder do
  subject(:recorder) do
    described_class.new(event_classes, max_size, **options)
  end

  let(:event_classes) { [] }
  let(:max_size) { 0 }
  let(:options) { {} }

  shared_context 'test buffer' do
    let(:buffer) { instance_double(Datadog::Profiling::Buffer) }

    before do
      allow(Datadog::Profiling::Buffer)
        .to receive(:new)
        .with(max_size)
        .and_return(buffer)
    end
  end

  describe '::new' do
    it do
      is_expected.to have_attributes(
        max_size: max_size
      )
    end

    context 'given events of different classes' do
      let(:event_classes) { [event_one.class, event_two.class] }
      let(:event_one) { Class.new(Datadog::Profiling::Event).new }
      let(:event_two) { Class.new(Datadog::Profiling::Event).new }

      it 'creates a buffer per class' do
        expect(Datadog::Profiling::Buffer)
          .to receive(:new)
          .with(max_size)
          .twice

        recorder
      end
    end
  end

  describe '#[]' do
    subject(:buffer) { recorder[event_class] }

    context 'given an event class that is defined' do
      let(:event_class) { Class.new }
      let(:event_classes) { [event_class] }

      it { is_expected.to be_a_kind_of(Datadog::Profiling::Buffer) }
    end
  end

  describe '#push' do
    include_context 'test buffer'

    let(:event_class) { Class.new(Datadog::Profiling::Event) }

    before do
      allow(buffer).to receive(:push)
      allow(buffer).to receive(:concat)
    end

    context 'given an event' do