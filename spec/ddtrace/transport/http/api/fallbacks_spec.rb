require 'spec_helper'

require 'ddtrace/transport/http/api/fallbacks'

RSpec.describe Datadog::Transport::HTTP::API::Fallbacks do
  context 'when implemented' do
    subject(:test_object) { test_class.new }

    let(:test_class) { Class.new { include Datadog::Transport::HTTP::API::Fallbacks } }

    describe '#fallbacks' do
      subject(:fallbacks) { test_object.fallbacks }

      it { is_expected.to eq({}) }
    end

    describe '#with_fallbacks' do
      subject(:with_fallbacks) { test_object.with_fallbacks(fallbacks) }

    