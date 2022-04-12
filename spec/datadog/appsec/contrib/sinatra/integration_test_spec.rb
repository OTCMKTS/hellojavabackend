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

 