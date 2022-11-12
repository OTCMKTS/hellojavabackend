require 'securerandom'
require 'rack/test'
require 'sinatra/base'

require 'datadog/tracing'
require 'datadog/tracing/metadata/ext'
require 'datadog/tracing/sampling/ext'
require 'datadog/tracing/contrib/sinatra/ext'
require 'datadog/tracing/contrib/sinatra/tracer'

require 'datadog/tracing/contrib/analytics_examples'
require 'datadog/tracing/contrib/support/spec_helper'
require 'rspec/expectations'

RSpec.describe 'Sinatra instrumentation' do
  include Rack::Test::Methods

  subject(:response) { get url }

  let(:configuration_options) { {} }
  let(:url) { '/' }
  let(:http_method) { 'GET' }
  let(:resource) { "#{http_method} #{url}" }
  let(:sinatra_routes) do
    lambda do
      get '/' do
        headers['X-Request-ID'] = 'test id'
        'ok'
      end

      get '/wildcard/*' do
        params['splat'][0]
      end

      get '/error' do
        raise 'test error'
      end

      get '/client_error' do
        halt 400, 'bad request'
      end

      get '/server_error' do
        halt 500, 'server error'
      end

      get '/erb' do
        headers['Cache-Control'] = 'max-age=0'

        erb :msg, locals: { msg: 'hello' }
      end

      get '/erb_literal' do
        erb '<%= msg %>', locals: { msg: 'hello' }
      end

      get '/span_resource' do
        'ok'
      end
    end
  end

  let(:app) { sinatra_app }

  let(:span) { spans.find { |x| x.name == Datadog::Tracing::Contrib::Sinatra::Ext::SPAN_REQUEST } }
  let(:route_span) { spans.find { |x| x.name == Datadog::Tracing::Contrib::Sinatra::Ext::SPAN_ROUTE } }
  let(:rack_span) { spans.find { |x| x.name == Datadog::Tracing::Contrib::Rack::Ext::SPAN_REQUEST } }

  before do
    Datadog.configure do |c|
      c.tracing.instrument :sinatra, configuration_options
    end
  end

  around do |example|
    # Reset before and after each example; don't allow global state to linger.
    Datadog.registry[:sinatra].reset_configuration!
    example.run
    Datadog.registry[:sinatra].reset_configuration!
  end

  shared_examples 'sinatra examples' do |opts = {}|
    context 'when configured' do
      context 'with default settings' do
        context 'and a simple request is made' do
          subject(:response) { get url }

          it do
            is_expected.to be_ok

            expect(trace.resource).to eq(resource)
            expect(rack_span.resource).to eq(resource)

            expect(span).to be_request_span parent: rack_span

            expect(route_span).to be_route_span parent: span, app_name: opts[:app_name]
          end

          it_behaves_like 'analytics for integration', ignore_global_flag: false do
            before { is_expected.to be_ok }

            let(:analytics_enabled_var) { Datadog::Tracing::Contrib::Sinatra::Ext::ENV_ANALYTICS_ENABLED }
            let(:analytics_sample_rate_var) { Datadog::Tracing::Contrib::Sinatra::Ext::ENV_ANALYTICS_SAMPLE_RATE }
          end

          it_behaves_like 'measured span for integration', true do
            before { is_expected.to be_ok }
          end

          context 'which sets X-Request-Id on the response' do
            it do
              subject
              skip('not matching app span') unless span.get_tag(Datadog::Tracing::Contrib::Sinatra::Ext::TAG_ROUTE_PATH)
              expect(span.get_tag('http.response.headers.x-request-id')).to eq('test id')
            end
          end
        end

        context 'and a request with a query string and fragment is made' do
          subject(:response) { get '/#foo?a=1' }

          it do
            is_expected.to be_ok

            expect(span.resource).to eq('GET /')
            expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_URL)).to eq('/')
          end
        end

        context 'and a request to a wildcard route is made' do
          subject(:response) { get '/wildcard/1/2/3' }

          context 'with matching app' do
            it do
              expect(response).to be_ok

              expect(span.resource).to eq('GET /wildcard/*')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_URL)).to eq('/wildcard/1/2/3')
              # expect(span.get_tag(Datadog::Tracing::Contrib::Sinatra::Ext::TAG_ROUTE_PATH)).to eq('/wildcard/*')
            end
          end
        end

        context 'and a request to a template route is made' do
          subject(:response) { get '/erb' }

          let(:root_span) { spans.find { |s| request_span.parent_id == s.span_id } }
          let(:request_span) { spans.find { |s| route_span.parent_id == s.span_id } }
          let(:route_span) { spans.find { |s| template_parent_span.parent_id == s.span_id } }
          let(:template_parent_span) { spans.find { |s| template_child_span.parent_id == s.span_id } }
          let(:template_child_span) { spans.find { |s| s.get_tag('sinatra.template_name') == 'layout' } }

          before do
            expect(response).to be_ok
          end

          describe 'the sinatra.request span' do
            subject(:span) { request_span }

            it do
              expect(span.resource).to eq('GET /erb')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_URL)).to eq('/erb')
            end

            it_behaves_like 'measured span for integration', true
          end

          describe 'the sinatra.render_template child span' do
            subject(:span) { template_parent_span }

            it do
              expect(span.name).to eq(Datadog::Tracing::Contrib::Sinatra::Ext::SPAN_RENDER_TEMPLATE)
              expect(span.resource).to eq('sinatra.render_template')
              expect(span.get_tag('sinatra.template_name')).to eq('msg')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('sinatra')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
                .to eq('render_template')
            end

            it_behaves_like 'measured span for integration', true
          end

          describe 'the sinatra.render_template grandchild span' do
            subject(:span) { template_child_span }

            it do
              expect(span.name).to eq(Datadog::Tracing::Contrib::Sinatra::Ext::SPAN_RENDER_TEMPLATE)
              expect(span.resource).to eq('sinatra.render_template')
              expect(span.get_tag('sinatra.template_name')).to eq('layout')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('sinatra')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
                .to eq('render_template')
            end

            it_behaves_like 'measured span for integration', true
          end
        end

        context 'and a request to a literal template route is made' do
          subject(:response) { get '/erb_literal' }

          let(:rack_span) { spans.find { |x| x.name == Datadog::Tracing::Contrib::Rack::Ext::SPAN_REQUEST } }
          let(:template_parent_span) { spans.find { |s| template_child_span.parent_id == s.span_id } }
          let(:template_child_span) { spans.find { |s| s.get_tag('sinatra.template_name') == 'layout' } }

          before do
            expect(response).to be_ok
            expect(spans).to have(5).items
          end

          describe 'the sinatra.request span' do
            it do
              expect(span.resource).to eq('GET /erb_literal')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::HTTP::TAG_URL)).to eq('/erb_literal')
              expect(span.parent_id).to eq(rack_span.span_id)
            end

            it_behaves_like 'measured span for integration', true
          end

          describe 'the sinatra.render_template child span' do
            subject(:span) { template_parent_span }

            it do
              expect(span.name).to eq(Datadog::Tracing::Contrib::Sinatra::Ext::SPAN_RENDER_TEMPLATE)
              expect(span.resource).to eq('sinatra.render_template')
              expect(span.get_tag('sinatra.template_name')).to be nil
              expect(span.parent_id).to eq(route_span.span_id)
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('sinatra')
              expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
                .to eq('render_template')
            end

            it_behaves_like 'mea