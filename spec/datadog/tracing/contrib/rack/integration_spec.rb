require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/auto_instrument_examples'

require 'datadog/tracing/contrib/rack/integration'

RSpec.describe Datadog::Tracing::Contrib::Rack::Integration do
  extend ConfigurationHelpers

  let(:integration) { described_class.new(:rack) }

  describe '.version' do
    subject(:version) { described_class.version }

    context 'when the "rack" gem is loaded' do
      include_context 'loaded gems', rack: described_class::MINIMUM_VERSION
      it { is_expected.to be_a_kind_of(Gem::Version) }
    end

    context 'when "rack" gem is not loaded' do
      include_context 'loaded gems', rack: nil
      it { is_expected.to be nil }
    end
  end

  describe '.loaded?' do
    subject(:loaded?) { described_class.loaded? }

    context 'when Rack is defined' do
      before { stub_const('Rack', Class.new) }

      it { is_expected.to be true }
    end

    context 'when Rack is not defined' do
      before { hide_const('Rack') }

      it { is_expected.to be false }
    end
  end

  describe '.compatible?' do
    subject(:compatible?) { described_class.compatible? }

    context 'when "rack" gem is loaded with a version' do
      context 'that is less than the minimum' do
        include_context 'loaded gems', rack: decrement_gem_version(described_class::MINIMUM_VERSION)
        it { is_expected.to be false }
      end

    