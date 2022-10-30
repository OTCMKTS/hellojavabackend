require 'datadog/tracing/contrib/support/spec_helper'

require 'datadog/tracing/contrib/redis/integration'

RSpec.describe Datadog::Tracing::Contrib::Redis::Integration do
  extend ConfigurationHelpers

  let(:integration) { described_class.new(:redis) }

  describe '.version' do
    subject(:version) { described_class.version }

    context 'when `redis` gem and `redis-client` are loaded' do
      include_context 'loaded gems',
        redis: described_class::MINIMUM_VERSION,
        'redis-client' => described_class::REDISCLIENT_MINIMUM_VERSION

      it { is_expected.to be_a_kind_of(Gem::Version) }
    end

    context 'when `redis` gem is loaded' do
      include_context 'loaded gems',
        redis: described_class::MINIMUM_VERSION,
        'redis-client' => nil

      it { is_expected.to be_a_kind_of(Gem::Version) }
    end

    context 'when `redis-client` gem is loaded' do
      include_context 'loaded gems',
        redis: nil,
        'redis-client' => described_class::REDISCLIENT_MINIMUM_VERSION

      it { is_expected.to be_a_kind_of(Gem::Version) }
    end

    context 'when `redis` gem and `redis-client` are not loaded' do
      include_context 'loaded gems', redis: nil, 'redis-client' => nil

      it { is_expected.to be nil }
    end
  end

  describe '.loaded?' do
    subject(:loaded?) { described_class.loaded? }

    context 'when `Redis` and `RedisClient` are de