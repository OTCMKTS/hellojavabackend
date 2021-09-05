require_relative '../../test'
require_relative '../../ext/app_types'
require_relative '../../ext/environment'
require_relative '../../ext/test'
require_relative 'ext'

module Datadog
  module CI
    module Contrib
      module Cucumber
        # Defines collection of instrumented Cucumber events
        class Formatter
          attr_reader :config, :current_feature_span, :current_step_span
          private :config
          private :current_feature_span, :current_step_span

          def initialize(config)
            @config = config

            bind_events(config)
          end

          def bind_events(config)
            config.on_event :test_case_started, &method(:on_test_case_started)
            config.on_event :test_case_finished, &method(:on_test_case_finished)
            config.on_event :test_step_started, &method(:on_test_step_started)
            config.on_event :test_step_finished, &method(:on_test_step_finished)
          end

          def on_test_case_started(event)
            @current_feature_span = CI::Test.trace(
              configuration[:operation_name],
  