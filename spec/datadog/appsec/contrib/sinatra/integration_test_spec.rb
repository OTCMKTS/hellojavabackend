require 'datadog/tracing/contrib/support/spec_helper'
require 'rack/test'

require 'securerandom'
require 'sinatra/base'

begin
  require 'rack/contrib/json_body_parser'
rescue LoadError
  # fallback for old rack-contrib
  require 'rack/contrib/post_body_content_type_parser'
end

require 'datadog/tracing'
require 'datadog/appsec'

RSpec.describe 'Sinatra integration tests' do
  include Rack::Test::Methods

  let(:sorted_spans) do
    chain = lambda do |start|
      loop.with_object([start]) do |_, o|
        # root reached (default)
        break o if o.last.parent_id == 0

        parent = spans.find { |span| span.span_id == o.last.parent_id }

        # root reached (distributed tracing)
        break o if parent.nil?

        o << parent
      end
    end
    sort = ->(list) { list.sort_by { |e| chain.call(e).count } }
    sort.call(spans)
  end

  let(:sinatra_span) { sorted_spans.reverse.find { |x| x.name == Datadog::Tracing::Contrib::Sinatra::Ext::SPAN_REQUEST } }
  let(:route_span) { sorted_spans.find { |x| x.name == Datadog::Tracing::Contrib::Sinatra::Ext::SPAN_ROUTE } }
  let(:rack_span) { sorted_spans.reverse.find { |x| x.name == Datadog::Tracing::Contrib::Rack::Ext::SPAN_REQUEST } }

  let(:appsec_enabled) { true }
  let(:tracing_enabled) { true }
  let(:appsec_ip_denylist) { nil }
  let(:appsec_user_id_denylist) { nil }
  let(:appsec_ruleset) { :recommended }

  let(:crs_942_100) do
    {
      'version' => '2.2',
      'metadata' => {
        'rules_version' => '1.4.1'
      },
      'rules' => [
        {
          'id' => 'crs-942-100',
          'name' => 'SQL Injection Attack Detected via libinjection',
          'tags' => {
            'type' => 'sql_injection',
            'crs_id' => '942100',
            'category' => 'attack_attempt'
          },
          'conditions' => [
            {
              'parameters' => {
                'inputs' => [
                  {
                    'address' => 'server.request.query'
                  },
                  {
                    'address' => 'server.request.body'
                  },
                  {
                    'address' => 'server.request.path_params'
                  },
                  {
                    'address' => 'grpc.server.request.message'
                  }
                ]
              },
              'operator' => 'is_sqli'
            }
          ],
          'transformers' => [
            'removeNulls'
          ],
          'on_match' => [
            'block'
          ]
        },
      ]
    }
  end

  before do
    Datadog.configure do |c|
      c.tracing.enabled = tracing_enabled
      c.tracing.instrument :sinatra

      c.appsec.enabled = appsec_enabled
      c.appsec.instrument :sinatra
      c.appsec.ip_denylist = appsec_ip_denylist
      c.appsec.user_id_denylist = appsec_user_id_denylist
      c.appsec.ruleset = appsec_ruleset

      # TODO: test with c.appsec.instrument :rack
    end
  end

  after do
    Datadog::AppSec.settings.send(:reset!)
    Datadog.registry[:rack].reset_configuration!
    Datadog.registry[:sinatra].reset_configuration!
  end

  context 'for an application' do
    # TODO: also test without Tracing: it should run without trace transport

    let(:middlewares) { [] }

    let(:app) do
      app_routes = routes
      app_middlewares = middlewares

      Class.new(Sinatra::Application) do
        app_middlewares.each { |m| use m }
        instance_exec(&app_routes)
      end
    end

    let(:triggers) do
      json = trace.send(:meta)['_dd.appsec.json']

      JSON.parse(json).fetch('triggers', []) if json
    end

    let(:remote_addr) { '127.0.0.1' }
    let(:client_ip) { remote_addr }

    let(:span) { rack_span }

    shared_examples 'a GET 200 span' do
      it { expect(span.get_tag('http.method')).to eq('GET') }
      it { expect(span.get_tag('http.status_code')).to eq('200') }
      it { expect(span.status).to eq(0) }

      context 'with appsec disabled' do
        let(:appsec_enabled) { false }

        it { expect(span.get_tag('http.method')).to eq('GET') }
        it { expect(span.get_tag('http.status_code')).to eq('200') }
        it { expect(span.status).to eq(0) }
      end
    end

    shared_examples 'a GET 403 span' do
      it { expect(span.get_tag('http.method')).to eq('GET') }
      it { expect(span.get_tag('http.status_code')).to eq('403') }
      it { expect(span.status).to eq(0) }

      context 'with appsec disabled' do
        let(:appsec_enabled) { false }

        it { expect(span.get_tag('http.method')).to eq('GET') }
        it { expect(span.get_tag('http.status_code')).to eq('200') }
        it { expect(span.status).to eq(0) }
      end
    end

    shared_examples 'a GET 404 span' do
      it { expect(span.get_tag('http.method')).to eq('GET') }
      it { expect(span.get_tag('http.status_code')).to eq('404') }
      it { expect(span.status).to eq(0) }

      context 'with appsec disabled' do
        let(:appsec_enabled) { false }

        it { expect(span.get_tag('http.method')).to eq('GET') }
        it { expect(span.get_tag('http.status_code')).to eq('404') }
        it { expect(span.status).to eq(0) }
      end
    end

    shared_examples 'a POST 200 span' do
      it { expect(span.get_tag('http.method')).to eq('POST') }
      it { expect(span.get_tag('http.status_code')).to eq('200') }
      it { expect(span.status).to eq(0) }

      context 'with appsec disabled' do
        let(:appsec_enabled) { false }

        it { expect(span.get_tag('http.method')).to eq('POST') }
        it { expect(span.get_tag('http.status_code')).to eq('200') }
        it { expect(span.status).to eq(0) }
      end
    end

    shared_examples 'a POST 403 span' do
      it { expect(span.get_tag('http.method')).to eq('POST') }
      it { expect(span.get_tag('http.status_code')).to eq('403') }
      it { expect(span.status).to eq(0) }

      context 'with appsec disabled' do
        let(:appsec_enabled) { false }

        it { expect(span.get_tag('http.method')).to eq('POST') }
        it { expect(span.get_tag('http.status_code')).to eq('200') }
        it { expect(span.status).to eq(0) }
      end
    end

    shared_examples 'a trace without AppSec tags' do
      it { expect(trace.send(:metrics)['_dd.appsec.enabled']).to be_nil }
      it { expect(trace.send(:meta)['_dd.runtime_family']).to be_nil }
      it { expect(trace.send(:meta)['_dd.appsec.waf.version']).to be_nil }
      it { expect(span.send(:meta)['http.client_ip']).to eq nil }
    end

    shared_examples 'a trace with AppSec tags' do
      it { expect(trace.send(:metrics)['_dd.appsec.enabled']).to eq(1.0) }
      it { expect(trace.send(:meta)['_dd.runtime_family']).to eq('ruby') }
      it { expect(trace.send(:meta)['_dd.appsec.waf.version']).to match(/^\d+\.\d+\.\d+/) }
      it { expect(span.send(:meta)['http.client_ip']).to eq client_ip }

      context 'with appsec disabled' do
        let(:appsec_enabled) { false }

        it_behaves_like 'a trace without AppSec tags'
      end
    end

    shared_examples 'a trace without AppSec events' do
      it { expect(spans.select { |s| s.get_tag('appsec.event') }).to be_empty }
      it { expect(trace.send(:meta)['_dd.appsec.triggers']).to be_nil }
    end

    shared_examples 'a trace with AppSec events' do
      it { expect(spans.select { |s| s.get_tag('appsec.event') }).to_not be_empty }
      it { expect(trace.send(:meta)['_dd.appsec.json']).to 