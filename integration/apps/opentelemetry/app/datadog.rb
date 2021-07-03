require 'datadog/demo_env'
require 'ddtrace'

require 'opentelemetry/sdk'
require 'datadog/opentelemetry'

Datadog.configure do |c|
  c.diagnostics.debug = true if Datadog::DemoEnv.feature?('debug')
  c.runtime_m