require 'datadog/tracing/contrib/support/spec_helper'
require 'rack/test'
require 'securerandom'
require 'rack'
require 'ddtrace'
require 'datadog/tracing/contrib/rack/middlewares'

RSpec.describe 'Rack integration tests' do
  include Rack::Test::Methods

  let(:rack_options) { {} }

  before do
    Datadog.configure do |c|
      c.tracing.instrument :rack, rack_options
    end
  end

  after { Datadog.registry[:rack].reset_configuration! }

  shared_examples 'a rack GET 200 span' do
    it do
      expect(span.name).to eq('rack.request')
      expect(span.span_type).to eq('web')
      expect(span.service).to eq(tracer.default_service)
      expect(span.resource).to eq('GET 200')
      expect(span.get_tag('http.method')).to eq('GET')
      expect(span.get_tag('http.status_code')).to eq('200')
      expect(span.status).to eq(0)
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('rack')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION)).to eq('request')
      expect(span.get_tag('span.kind')).to eq('server')
    end
  end

  context 'for an application' do
    let(:app) do
      app_routes = routes

      Rack::Builder.new do
        use Datadog::Tracing::Contrib::Rack::TraceMiddleware
        instance_eval(&app_routes)
      end.to_app
    end

    context 'with no routes' do
      # NOTE: Have to give a Rack app at least one route.
      let(:routes) do
        proc do
          map '/no/routes' do
            run(proc { |_env| })
          end
        end
      end

      before do
        is_expected.to be_not_found
        expect(spans).to have(1).items
      end

      describe 'GET request' do
        subject(:response) { get '/not/exists/' }

        it do
          expect(span.name).to eq('rack.request')
          expect(span.span_type).to eq('web')
          expect(span.service).to eq(Datadog.configuration.service)
          expect(span.resource).to eq('GET 404')
          expect(span.get_tag('http.method')).to eq('GET')
          expect(span.get_tag('http.status_code')).to eq('404')
          expect(span.get_tag('http.url')).to eq('/not/exists/')
          expect(span.get_tag('http.base_url')).to eq('http://example.org')
          expect(span.status).to eq(0)
          expect(span).to be_root_span
          expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
            .to eq('rack')
          expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
            .to eq('request')
          expect(span.get_tag('span.kind'))
            .to eq('server')
        end
      end
    end

    context 'with a basic route' do
      let(:routes) do
        proc do
          map '/success/' do
            run(proc { |_env| [200, { 'Content-Type' => 'text/html' }, ['OK']] })
          end
        end
      end

      before do
        is_expected.to be_ok
        expect(spans).to have(1).items
      end

      describe 'GET request' do
        subject(:response) { get route }

        context 'without parameters' do
          let(:route) { '/success/' }

          it_behaves_like 'a rack GET 200 span'

          context 'and default quantization' do
            let(:rack_options) { { quantize: {} } }

            it do
              expect(span.get_tag('http.url')).to eq('/success/')
              expect(span.get_tag('http.base_url')).to eq('http://example.org')
              expect(span).to be_root_span
            end
          end

          context 'and quantization activated for URL base' do
            let(:rack_options) { { quantize: { base: :show } } }

            it do
              expect(span.get_tag('http.url')).to eq('http://example.org/success/')
              expect(span.get_tag('http.base_url')).to be_nil
              expect(span).to be_root_span
            end
          end

          it { expect(trace.resource).to eq('GET 200') }
        end

        context 'with query string parameters' do
          let(:route) { '/success?foo=bar' }

          context 'and default quantization' do
            let(:rack_options) { { quantize: {} } }

            it_behaves_like 'a rack GET 200 span'

            it do
              expect(span.get_tag('http.url')).to eq('/success?foo')
              expect(span.get_tag('http.base_url')).to eq('http://example.org')
              expect(span).to be_root_span
            end
          end

          context 'and quantization activated for the query' do
            let(:rack_options) { { quantize: { query: { show: ['foo'] } } } }

            it_behaves_like 'a rack GET 200 span'

            it do
              expect(span.get_tag('http.url')).to eq('/success?foo=bar')
              expect(span.get_tag('http.base_url')).to eq('http://example.org')
              expect(span).to be_root_span
            end
          end
        end

        context 'with REQUEST_URI being a path' do
          subject(:response) { get '/success?foo=bar', {}, 'REQUEST_URI' => '/success?foo=bar' }

          context 'and default quantization' do
            let(:rack_options) { { quantize: {} } }

            it_behaves_like 'a rack GET 200 span'

            it do
              # Since REQUEST_URI is set (usually provided by WEBrick/Puma)
              # it uses REQUEST_URI, which has query string parameters.
              # However, that query string will be quantized.
              expect(span.get_tag('http.url')).to eq('/success?foo')
              expect(span.get_tag('http.base_url')).to eq('http://example.org')
              expect(span).to be_root_span
            end
          end

          context 'and quantization activated for the query' do
            let(:rack_options) { { quantize: { query: { show: ['foo'] } } } }

            it_behaves_like 'a rack GET 200 span'

            it do
              # Since REQUEST_URI is set (usually provided by WEBrick/Puma)
              # it uses REQUEST_URI, which has query string parameters.
              # The query string will not be quantized, per the option.
              expect(span.get_tag('http.url')).to eq('/success?foo=bar')
              expect(span.get_tag('http.base_url')).to eq('http://example.org')
              expect(span).to be_root_span
            end
          end

          context 'and quantization activated for base' do
            let(:rack_options) { { quantize: { base: :show } } }

            it_behaves_like 'a rack GET 200 span'

            it do
              # Since REQUEST_URI is set (usually provided by WEBrick/Puma)
              # it uses REQUEST_URI, which has query string parameters.
              # The query string will not be quantized, per the option.
              expect(span.get_tag('http.url')).to eq('http://example.org/success?foo')
              expect(span.get_tag('http.base_url')).to be_nil
              expect(span).to be_root_span
            end
          end
        end

        context 'with REQUEST_URI containing base URI' do
          subject(:response) { get '/success?foo=bar', {}, 'REQUEST_URI' => 'http://example.org/success?foo=bar' }

          context 'and default quantization' do
            let(:rack_options) { { quantize: {} } }

            it_behaves_like 'a rack GET 200 span'

            it do
              # Since REQUEST_URI is set (usually provided by WEBrick/Puma)
              # it uses REQUEST_URI, which has query string parameters.
              # However, that query string will be quantized.
              expect(span.get_tag('http.url')).to eq('/success?foo')
              expect(span.get_tag('http.base_url')).to eq('http://example.org')
              expect(span).to be_root_span
            end
          end

          context 'and quantization activated for the query' do
            let(:rack_options) { { quantize: { query: { show: ['foo'] } } } }

            it_behaves_like 'a rack GET 200 span'

            it do
  