require_relative '../../configuration/settings'

module Datadog
  module Tracing
    module Contrib
      module Rails
        module Configuration
          # Custom settings for the Rails integration
          # @public_api
          class Settings < Contrib::Configuration::Settings
            def initialize(options = {})
              super(options)

              # NOTE: Eager load these
              #       Rails integration is responsible for orchestrating other integrations.
              #       When using environment variables, settings will not be automatically
              #       filled because nothing explicitly calls them. They must though, so
              #       integrations like ActionPack can receive the value as it should.
              #       Trigger these manually to force an eager load and propagate them.
              analytics_enabled
              analytics_sample_rate
            end

            option :enabled do |o|
              o.default { env_to_bool(Ext::ENV_ENABLED, true) }
              o.lazy
            end

            option :analytics_enabled do |o|