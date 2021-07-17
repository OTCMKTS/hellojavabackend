require_relative 'boot'
require 'datadog/tracing/runtime/metrics'

# require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"
require "action_cable/engine"
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

class TraceMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    Datadog::Tracing.trace('web.request', service: 'acme', resource: env['REQUEST_PATH']) do |span, trace|
      Datadog::Runtime::Metrics.associate_trace(trace)
      @app.call(env)
    end
  end
end

class ShortCircuitMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    return [200, {}, []]
  end
end

class ErrorMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
    raise
  end
end

class CustomError < StandardError
  def message
    'Custom error message!'
  end
end

class CacheM