require 'spec_helper'

require 'ddtrace/transport/http/api'

RSpec.describe Datadog::Transport::HTTP::API do
  describe '.defaults' do
    subject(:defaults) { described_class.defaults }

    it { is_expected.to be_a_kind_of(Datadog::Transport::HTTP::API::Map) }

    it do
      is_expected.to include(
        described_class::V4 => kind_of(Datadog::Transport::HTTP::API::Spec),
        described_class::V3 => kind_of(Datadog::Transport::HTTP::API::Spec),
      )

      defaults[described_class::V4].tap do |v4|
  