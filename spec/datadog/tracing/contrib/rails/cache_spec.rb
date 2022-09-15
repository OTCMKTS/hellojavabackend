require 'spec_helper'
require 'datadog/tracing/contrib/analytics_examples'

require 'securerandom'
require 'datadog/tracing/contrib/rails/ext'

require 'datadog/tracing/contrib/rails/rails_helper'

RSpec.describe 'Rails cache' do
  include_context 'Rails test application'

  before do
    Datadog.configuration.tracing[:active_support][:cache_service] = 'rails-cache'
  end

  after do
    Datadog.configuration.tracing[:active_support].reset!
  end

  before { app }

  let(:cache) { Rails.cache }

  let(:key) { 'custom-key' }
  let(:multi_keys) { %w[custom-key-1 custom-key-2 custom-key-3] }

  shared_examples 'a no-op when instrumentation is disabled' do
    context 'disabled at integration level' do
      before { Datadog.configuration.tracing[:active_support].enabled = false }
      after { Datadog.configuration.tracing[:active_support].reset! }

      it 'does not instrument' do
        expect { subject }.to_not(change { fetch_spans })
      end
    end

    context 'disabled at tracer level' do
      before do
        Datadog.configure do |c|
          c.tracing.enabled = false
        end
      end

      after { Datadog.configuration.tracing.reset! }

      it 'does not instrument' do
        expect { subject }.to_not(change { fetch_spans })
      end
    end
  end

  describe '#read' do
    subject(:read) { cache.read(key) }

    before { cache.write(key, 50) }

    it_behaves_like 'a no-op when instrumentation is disabled'

    it_behaves_like 'measured span for integration', false do
      before { read }

      let(:span) { spans.first }
    end

    it do
      expect(read).to eq(50)

      expect(spans).to have(2).items
      get, set = spans
      expect(get.name).to eq('rails.cache')
      expect(get.span_type).to eq('cache')
      expect(get.resource).to eq('GET')
      expect(get.service).to eq('rails-cache')
      expect(get.get_tag('rails.cache.backend').to_s).to eq('file_store')
      expect(get.get_tag('rails.cache.key')).to eq(key)
      expect(set.name).to eq('rails.cache')

      expect(get.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
        .to eq('active_support')
      expect(get.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
        .to eq('cache')
      expect(get.get_tag(Datadog::Tracing::Metadata::Ext::TAG_PEER_SERVICE))
        .to eq('rails-cache')

      expect(set.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
        .to eq('active_support')
      expect(set.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
        .to eq('cache')
      expect(set.get_tag(Datadog::Tracing::Metadata::Ext::TAG_PEER_SERVICE))
        .to eq('rails-cache')
    end
  end

  describe '#read_multi' do
    subject(:read_multi) { cache.read_multi(*multi_keys) }

    before { multi_keys.each { |key| cache.write(key, 50 + key[-1].to_i) } }

    it_behaves_like 'a no-op when instrumentation is disabled'

    it_behaves_like 'measured span for integration', false do
      before { read_multi }

      let(:span) { spans[0] }
    end

    it do
      expect(read_multi).to eq(Hash[multi_keys.zip([51, 52, 53])])
      expect(spans).to have(1 + multi_keys.size).items
      get = spans[0]
      expect(get.name).to eq('rails.cache')
      expect(get.span_type).to eq('cache')
      expect(get.resource).to eq('MGET')
      expect(get.service).to eq('rails-cache')
      expect(get.get_tag('rails.cache.backend').to_s).to eq('file_store')
      expect(JSON.parse(get.get_tag('rails.cache.keys'))).to eq(multi_keys)
      expect(get.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
        .to eq('active_support')
      expect(get.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
        .to eq('cache')
      expect(get.get_tag(Datadog::Tracing::Metadata::Ext::TAG_PEER_SERVICE))
        .to eq('rails-cache')

      spans[1..-1].each do |set|
        expect(set.name).to eq('rails.cache')
        expect(set.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
          .to eq('active_support')
        expect(set.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
          .to eq('cache')
        expect(set.get_tag(Datadog::Tracing::Metadata::Ext::TAG_PEER_SERVICE))
          .to eq('rails-cache')
      end
    end
  end

  describe '#write' do
    subject(:write) { cache.write(key, 50) }

    it_behaves_like 'a no-op when instrumentation is disabled'

    it_behaves_like 'measured span for integration', false do
      before { write }
    end

    it do
      write
      expect(span.name).to eq('rails.cache')
      expect(span.span_type).to eq('cache')
      expect(span.resource).to eq('SET')
      expect(span.service).to eq('ra