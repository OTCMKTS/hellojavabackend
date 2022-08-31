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

        context 'with sub-route' do
          let(:route) { '/success/100' }

          it_behaves_like 'a rack GET 200 span'

          it do
            expect(span.get_tag('http.url')).to eq('/success/100')
            expect(span.get_tag('http.base_url')).to eq('http://example.org')
            expect(span).to be_root_span
          end
        end
      end

      describe 'POST request' do
        subject(:response) { post route }

        context 'without parameters' do
          let(:route) { '/success/' }

          it do
            expect(span.name).to eq('rack.request')
            expect(span.span_type).to eq('web')
            expect(span.service).to eq(Datadog.configuration.service)
            expect(span.resource).to eq('POST 200')
            expect(span.get_tag('http.method')).to eq('POST')
            expect(span.get_tag('http.status_code')).to eq('200')
            expect(span.get_tag('http.url')).to eq('/success/')
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
    end

    context 'when `request_queuing` enabled' do
      let(:routes) do
        proc do
          map '/request_queuing_enabled' do
            run(proc { |_env| [200, { 'Content-Type' => 'text/html' }, ['OK']] })
          end
        end
      end

      describe 'when request queueing includes the request time' do
        let(:rack_options) { { request_queuing: :include_request } }

        it 'creates web_server_span and rack span' do
          get 'request_queuing_enabled',
            nil,
            { Datadog::Tracing::Contrib::Rack::QueueTime::REQUEST_START => "t=#{Time.now.to_f}" }

          expect(trace.resource).to eq('GET 200')

          expect(spans).to have(2).items

          server_queue_span = spans[0]
          rack_span = spans[1]

          expect(server_queue_span).to be_root_span
          expect(server_queue_span.name).to eq(Datadog::Tracing::Contrib::Rack::Ext::SPAN_HTTP_SERVER_QUEUE)
          expect(server_queue_span.span_type).to eq('proxy')
          expect(server_queue_span.service).to eq('web-server')
          expect(server_queue_span.resource).to eq('http_server.queue')
          expect(server_queue_span.get_tag('component')).to eq('rack')
          expect(server_queue_span.get_tag('operation')).to eq('queue')
          expect(server_queue_span.get_tag('peer.service')).to eq('web-server')
          expect(server_queue_span.status).to eq(0)
          expect(server_queue_span.get_tag('span.kind')).to eq('server')

          expect(rack_span.name).to eq(Datadog::Tracing::Contrib::Rack::Ext::SPAN_REQUEST)
          expect(rack_span.span_type).to eq('web')
          expect(rack_span.service).to eq(tracer.default_service)
          expect(rack_span.resource).to eq('GET 200')
          expect(rack_span.get_tag('http.method')).to eq('GET')
          expect(rack_span.get_tag('http.status_code')).to eq('200')
          expect(rack_span.status).t