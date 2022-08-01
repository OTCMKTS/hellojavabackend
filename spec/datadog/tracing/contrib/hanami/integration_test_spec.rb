require_relative './support/hanami_helpers'
require_relative './support/custom_matchers'
require 'rack'
require 'rack/test'
require 'ddtrace'
require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/rack/ext'
require 'datadog/tracing/contrib/hanami/ext'

RSpec.describe 'Hanami instrumentation' do
  include Rack::Test::Methods
  include_context 'Hanami test application'

  let(:rack_span) { spans.find { |s| s.name == Datadog::Tracing::Contrib::Rack::Ext::SPAN_REQUEST } }
  let(:routing_span) { spans.find { |s| s.name == Datadog::Tracing::Contrib::Hanami::Ext::SPAN_ROUTING } }
  let(:action_span) { spans.find { |s| s.name == Datadog::Tracing::Contrib::Hanami::Ext::SPAN_ACTION } }
  let(:render_span) { spans.find { |s| s.name == Datadog::Tracing::Contrib::Hanami::Ext::SPAN_RENDER } }

  context 'when given a simple success endpoint' do
    subject(:response) { get 'simple_success' }

    it 'creates 3 spans' do
      expect(response.status).to eq(200)

      expect(spans).to have(3).items

      expect(rack_span).to be_hanami_rack_span.with(resource: 'GET 200')
      expect(routing_span).to be_hanami_routing_span.with(parent: rack_span, resource: 'GET')
      expect(render_span).to be_hanami_render_span.with(
        parent: routing_span,
        resource: 'Hanami::Routing::Default::NullAction'
      )
    end
  end

  context 'when given a GET /books endpoint' do
    subject(:response) { get 'books' }

    it 'creates 4 spans' do
      expect(response.status).to eq(200)

      expect(spans).to have(4).items

      expect(rack_s