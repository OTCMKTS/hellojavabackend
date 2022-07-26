require 'datadog/tracing/contrib/support/spec_helper'
require 'elasticsearch'

require 'ddtrace'
require 'datadog/tracing/contrib/elasticsearch/quantize'

RSpec.describe Datadog::Tracing::Contrib::Elasticsearch::Quantize do
  describe '#format_url' do
    shared_examples_for 'a quantized URL' do |url, expected_url|
      subject(:quantized_url) { described_class.format_url(url) }

      it { is_expected.to eq(expected_url) }
    end

    context 'when the URL contains an ID' do
      it_behaves_like 'a quantized URL', '/my/thing/1', '/my/thing/?'
      it_behaves_like 'a quantized URL', '/my/thing/1/', '/my/thing/?/'
      it_behaves_like 'a quantized URL', '/my/thing/1/is/cool', '/my/thing/?/is/cool'
      it_behaves_like 'a quantized URL', '/my/thing/1?is=cool', '/my/thing/??is=cool'
      it_behaves_like 'a quantized URL', '/my/thing/1two3/z', '/my/thing/?/z'
      it_behaves_like 'a quantized URL', '/my/thing/1two3/z/', '/my/thing/?/z/'
      it_behaves_like 'a quantized URL', '/my/thing/1two3/z?a=b', '/my/thing/?/z?a=b'
      it_behaves_like 'a quantized URL', '/my/thing/1two3/z?a=b123', '/my/thing/?/z?a=b?'
      it_behaves_like 'a quantized URL', '/my/thing/1two3/abc', '/my/thing/?/abc'
      it_behaves_like 'a quantized URL', '/my/thing/1two3/abc/', '/my/thing/?/abc/'
      it_behaves_like 'a quantized URL', '/my/thing231/1two3/abc/', '/my/thing?/?/abc/'
      it_behaves_like 'a quantized URL',
        '/my/thing/1447990c-811a-4a83-b7e2-c3e8a4a6ff54/_termvector',
        '/my/thing/?/_termvector'
      it_behaves_like 'a quantized URL',
        'app_prod/user/1fff2c9dc2f3e/_termvector',
        'app_prod/user/?/_termvector'
    end

    context 'when the URL looks like an index' do
      it_behaves_like 'a quantized URL', '/my123456/thing', '/my?/thing'
      it_behaves_like 'a quantized URL', '/my123456more/thing', '/my?more/thing'
      it_behaves_like 'a quantized URL', '/my123456and789/thing', '/my?and?/thing'
    end

    context 'when the URL has both an index and ID' do
      it_behaves_like 'a quantized URL', '/my123/thing/456789', '/my?/thing/?'
    end
  end

  describe 