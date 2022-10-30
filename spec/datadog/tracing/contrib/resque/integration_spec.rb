require 'datadog/tracing/contrib/support/spec_helper'

require 'datadog/tracing/contrib/resque/integration'

RSpec.describe Datadog::Tracing::Contrib::Resque::Integration do
  extend ConfigurationHelpers

  let(:integration) { described_class.new(:resque) }

  describe '.version' do
    subject(:version) { described_class.version }

    context 'when the "resque" gem is loaded' do
      include_context 'loaded gems', resque: described_class::MINIMUM_VERSION
      it { is_expected.to be_a_kind_of(Gem::Version) }
    end

    context 'when "resque" gem is not loaded' do
      include_context 'loaded gems', resque: nil
      it { is_expected.to be nil }
    end
  end

  describe '.loaded?' do
    subject(:loaded?) { described_class.loaded? }

    context 'when Resque is defined' do
      before { stub_const('Resque', Class.new) }

      it { is_expected.to be true }
    end

    context 'when Resque is not defined' do
      before { hide_const('Resque') }

      it { is_expected.to be false }
    end
 