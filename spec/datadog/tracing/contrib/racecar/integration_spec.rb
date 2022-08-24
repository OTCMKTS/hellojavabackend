require 'datadog/tracing/contrib/support/spec_helper'

require 'datadog/tracing/contrib/racecar/integration'

RSpec.describe Datadog::Tracing::Contrib::Racecar::Integration do
  extend ConfigurationHelpers

  let(:integration) { described_class.new(:racecar) }

  describe '.version' do
    subject(:version) { described_class.version }

    context 'when the "racecar" gem is loaded' do
      include_context 'loaded gems', racecar: described_class::MINIMUM_VERSION
      it { is_expected.to be_a_kind_of(Gem::Version) }
    end

    context 'when "racecar" gem is not loaded' do
      include_context 'loaded gems', racecar: nil
      it { is_expected.to be nil }
    end
  end

  describe '.loaded?' do
    subject(:loaded?) { described_class.loaded? }

    context 'when neither Racecar or ActiveSupport::Notifications are defined' do
      before do
        hide_const('Racecar')
        hide_const('ActiveSupport::Notifications')
      end

      it { is_expected.to be false }
    end

    context 'when only Racecar is defined' do
      before do
        stub_const('Racecar', Class.new)
        hide_const('ActiveSupport::Notifications')
      end

      it { is_expected.to be false }
    end

    context 'when only ActiveSupport::Notifications is defined' do
      before do
        hide_const('Racecar')
        stub_const('ActiveSupport::Noti