$LOAD_PATH.unshift File.expand_path('..', __dir__)
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

Thread.main.name = 'Thread.main' unless Gem::Version.new(RUBY_VERSION) < Gem::Version.new('2.3')

require 'pry'
require 'rspec/collection_matchers'
require 'rspec/wait'
require 'webmock/rspec'
require 'climate_control'

# Needed for calling JRuby.reference below
require 'jruby' if RUBY_ENGINE == 'jruby'

if (ENV['SKIP_SIMPLECOV'] != '1') && !RSpec.configuration.files_to_run.all? { |path| path.include?('/benchmark/') }
  # +SimpleCov.start+ must be invoked before any application code is loaded
  require 'simplecov'
  SimpleCov.start do
    formatter SimpleCov::Formatter::SimpleFormatter
  end
end

require 'datadog/core/encoding'
require 'datadog/tracing/tracer'
require 'datadog/tracing/span'

require 'support/configuration_helpers'
require 'support/container_helpers'
require 'support/core_helpers'
require 'support/faux_transport'
require 'support/faux_writer'
require 'support/health_metric_helpers'
require 'support/http_helpers'
require 'support/log_helpers'
require 'support/metric_helpers'
require 'support/network_helpers'
require 'support/object_helpers'
require 'support/object_space_helper'
require 'support/platform_helpers'
require 'support/rack_support'
require 'support/span_helpers'
require 'support/spy_transport'
require 'support/synchronization_helpers'
require 'support/test_helpers'
require 'support/tracer