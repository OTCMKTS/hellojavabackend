require 'datadog/tracing/contrib/support/spec_helper'

require 'datadog/tracing/analytics'
require 'datadog/tracing/metadata/ext'
require 'datadog/tracing/span'
require 'datadog/tracing/contrib/analytics'

RSpec.describe Datadog::Tracing::Contrib::Analytics do
  describe '::enabled?' do
    context 'when flag is not provided' do
      subject(:enabled?) { described_class.enabled? }

      it { is_expected.to be false }
    end

    context 'when flag is nil' do
      subject(:enabled?) { described_class.enabled?(nil) }

      it { is_expected.to be false }
    end

    context 'when flag is true' do
      subject(:enabled?) { described_class.enabled?(true) }

      it { is_expected.to be true }
    end

    context 'when flag is false' do
      subject(:enabled?) { described_class.enabled?(false) }

      it { is_expected.to be false }
    end
  end

  describe '::set_sample_rate' do
    subject(:set_sample_rate) { described_class.set_sample_rate(span, sample_rate) }

    let(:span) { instance_double(Datadog::Tracing::Span) }

    context 'when sample rate is nil' do
      let(:sample_rate) { nil }

      it 'does not set the tag' do
        expect(span).to_not receive(:set_metric)
        set_sample_rate
      end
    end

    context 'when a sample rate is given' do
      let(:sample_rate) { 0.5 }

      it 'sets the tag' do
        expect(span).to receive(:set_metric)
          .with(
            Datadog::Tracing::Metadata::Ext: