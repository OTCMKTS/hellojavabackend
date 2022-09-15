require 'datadog/tracing/contrib/rails/rails_helper'

RSpec.describe 'Rails middleware' do
  include Rack::Test::Methods
  include_context 'Rails test application'

  let(:routes) { { '/' => 'test#index' } }
  let(:use_rack) { true }
  let(:rails_options) { {} }
  let(:controllers) { [controller] }

  let(:controller) do
    stub_const(
      'TestController',
      Class.new(ActionController::Base) do
        def index
          head :ok
        end
      end
    )
  end

  RSpec::Matchers.define :have_kind_of_middleware do |expected|
    match do |actual|
      while actual
        return true if actual.class <= expected

        without_warnings { actual = actual.instance_variable_get(:@app) }
      end
      false
    end
  end

  before do
    Datadog.configure do |c|
      c.tracing.instrument :rack if use_rack
      c.tracing.instrument :rails, rails_options
    end
  end

  context 'with middleware' do
    context 'that does nothing' do
      let(:middleware) do
        stub_const(
          'PassthroughMiddleware',
          Class.new do
            def initialize(app)
              @app = app
            end

            def call(env)
              @app.call(env)
            end
          end
        )
      end

      context 'and added after tracing is enabled' do
        before do
          passthrough_middleware = middleware
          rails_test_application.configure { config.app_middleware.use passthrough_middleware }
        end

        context 'with #middleware_names' do
          let(:use_rack) { false }
          let(:rails_options) { super().merge!(middleware_names: true) }

          it do
            get '/'
            expect(app).to have_kind_of_middleware(middleware)
            expect(last_response).to be_ok
          end
        end
      end
    end

    context 'that itself creates a span' do
      let(:middleware) do
        stub_const(
          'CustomSpanMiddleware',
          Class.new do
            def initialize(app)
              @app = app
            end

            def call(env)
              Datadog::Tracing.trace('custom.test') do
                @app.call(env)
              end
            end
          end
        )
      end

      context 'and added after tracing is enabled' do
        before do
          custom_span_middleware = middleware
          rails_test_application.configure { config.app_middleware.use custom_span_middleware }
        end

        context 'with #middleware_names' do
          let(:use_rack) { false }
          let(:rails_options) { super().merge!(middleware_names: true) }
          let(:span) { spans.find { |s| s.name == 'rack.request' } }

          it do
            get '/'
            expect(trace.resource).to eq('TestController#index')

            # This is flaky: depending on test order, this will be the middleware name or
            # it will be GET 200. This is because env['RESPONSE_MIDDLEWARE'] sometimes isn't
            # set, which causes it to default