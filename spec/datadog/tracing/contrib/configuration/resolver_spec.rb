require 'datadog/tracing/contrib/support/spec_helper'

require 'datadog/tracing/contrib/configuration/resolver'

RSpec.describe Datadog::Tracing::Contrib::Configuration::Resolver do
  subject(:resolver) { described_class.new }

  let(:config) { double('config') }

  describe '#resolve' do
    subject(:resolve) { resolver.resolve(value) }

    let(:value) { 'value' }

    context 'with a matcher' do
      before { resolver.add(added_matcher, config) }

      context 'that matches' do
        let(:added_matcher) { value }

        it { is_expected.to be config }
      end

      context 'that does not match' do
        let(:added_matcher) { :different_value }

        it { is_expected.to be nil }
      end
    end

    context 'without a matcher' do
      it { is_expected.to be nil }
    end

    context 'with two matching matchers' do
      before do
        resolver.add(first_matcher, :first)
        resolver.add(second_matcher, :second)
      end

      let(:first_matcher) { 'value' }
      let(:second_matcher) { 'value' }

      it 'retu