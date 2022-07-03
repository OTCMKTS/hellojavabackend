
require 'datadog/profiling/spec_helper'
require 'datadog/profiling/stack_recorder'

RSpec.describe Datadog::Profiling::StackRecorder do
  before { skip_if_profiling_not_supported(self) }

  let(:numeric_labels) { [] }
  let(:cpu_time_enabled) { true }
  let(:alloc_samples_enabled) { true }

  subject(:stack_recorder) do
    described_class.new(cpu_time_enabled: cpu_time_enabled, alloc_samples_enabled: alloc_samples_enabled)
  end

  # NOTE: A lot of libdatadog integration behaviors are tested in the Collectors::Stack specs, since we need actual
  # samples in order to observe what comes out of libdatadog

  def active_slot
    described_class::Testing._native_active_slot(stack_recorder)
  end

  def slot_one_mutex_locked?
    described_class::Testing._native_slot_one_mutex_locked?(stack_recorder)
  end

  def slot_two_mutex_locked?
    described_class::Testing._native_slot_two_mutex_locked?(stack_recorder)
  end

  describe '#initialize' do
    describe 'locking behavior' do
      it 'sets slot one as the active slot' do
        expect(active_slot).to be 1
      end

      it 'keeps the slot one mutex unlocked' do
        expect(slot_one_mutex_locked?).to be false
      end

      it 'keeps the slot two mutex locked' do
        expect(slot_two_mutex_locked?).to be true
      end
    end
  end

  describe '#serialize' do
    subject(:serialize) { stack_recorder.serialize }

    let(:start) { serialize[0] }
    let(:finish) { serialize[1] }
    let(:encoded_pprof) { serialize[2] }

    let(:decoded_profile) { ::Perftools::Profiles::Profile.decode(encoded_pprof) }

    it 'debug logs profile information' do
      message = nil

      expect(Datadog.logger).to receive(:debug) do |&message_block|
        message = message_block.call
      end

      serialize

      expect(message).to include start.iso8601
      expect(message).to include finish.iso8601
    end

    describe 'locking behavior' do
      context 'when slot one was the active slot' do
        it 'sets slot two as the active slot' do
          expect { serialize }.to change { active_slot }.from(1).to(2)
        end

        it 'locks the slot one mutex' do
          expect { serialize }.to change { slot_one_mutex_locked? }.from(false).to(true)
        end

        it 'unlocks the slot two mutex' do
          expect { serialize }.to change { slot_two_mutex_locked? }.from(true).to(false)
        end
      end

      context 'when slot two was the active slot' do
        before do
          # Trigger serialization once, so that active slots get flipped
          stack_recorder.serialize
        end

        it 'sets slot one as the active slot' do
          expect { serialize }.to change { active_slot }.from(2).to(1)
        end

        it 'unlocks the slot one mutex' do
          expect { serialize }.to change { slot_one_mutex_locked? }.from(true).to(false)
        end

        it 'locks the slot two mutex' do
          expect { serialize }.to change { slot_two_mutex_locked? }.from(false).to(true)
        end
      end
    end

    context 'when the profile is empty' do
      it 'uses the current time as the start and finish time' do
        before_serialize = Time.now.utc
        serialize
        after_serialize = Time.now.utc

        expect(start).to be_between(before_serialize, after_serialize)
        expect(finish).to be_between(before_serialize, after_serialize)
        expect(start).to be <= finish
      end

      context 'when all profile types are enabled' do
        let(:cpu_time_enabled) { true }
        let(:alloc_samples_enabled) { true }

        it 'returns a pprof with the configured sample types' do
          expect(sample_types_from(decoded_profile)).to eq(
            'cpu-time' => 'nanoseconds',
            'cpu-samples' => 'count',
            'wall-time' => 'nanoseconds',
            'alloc-samples' => 'count',
          )
        end
      end

      context 'when cpu-time is disabled' do
        let(:cpu_time_enabled) { false }
        let(:alloc_samples_enabled) { true }

        it 'returns a pprof without the cpu-type type' do
          expect(sample_types_from(decoded_profile)).to eq(
            'cpu-samples' => 'count',
            'wall-time' => 'nanoseconds',
            'alloc-samples' => 'count',
          )
        end
      end

      context 'when alloc-samples is disabled' do
        let(:cpu_time_enabled) { true }
        let(:alloc_samples_enabled) { false }

        it 'returns a pprof without the alloc-samples type' do
          expect(sample_types_from(decoded_profile)).to eq(
            'cpu-time' => 'nanoseconds',
            'cpu-samples' => 'count',
            'wall-time' => 'nanoseconds',
          )
        end
      end

      context 'when all optional types are disabled' do
        let(:cpu_time_enabled) { false }
        let(:alloc_samples_enabled) { false }

        it 'returns a pprof with without the optional types' do
          expect(sample_types_from(decoded_profile)).to eq(
            'cpu-samples' => 'count',
            'wall-time' => 'nanoseconds',
          )
        end
      end

      it 'returns an empty pprof' do
        expect(decoded_profile).to have_attributes(
          sample: [],
          mapping: [],
          location: [],
          function: [],
          drop_frames: 0,
          keep_frames: 0,
          time_nanos: Datadog::Core::Utils::Time.as_utc_epoch_ns(start),
          period_type: nil,
          period: 0,
          comment: [],
        )
      end

      def sample_types_from(decoded_profile)
        strings = decoded_profile.string_table
        decoded_profile.sample_type.map { |sample_type| [strings[sample_type.type], strings[sample_type.unit]] }.to_h
      end
    end

    context 'when profile has a sample' do
      let(:metric_values) { { 'cpu-time' => 123, 'cpu-samples' => 456, 'wall-time' => 789, 'alloc-samples' => 4242 } }
      let(:labels) { { 'label_a' => 'value_a', 'label_b' => 'value_b' }.to_a }

      let(:samples) { samples_from_pprof(encoded_pprof) }
