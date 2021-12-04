require_relative 'configuration/resolver'
require_relative 'configuration/settings'

module Datadog
  module Tracing
    module Contrib
      # Defines configurable behavior for integrations.
      #
      # This module is responsible for coordination between
      # the configuration resolver and default configuration
      # fallback.
      module Configurable
        def self.included(base)
          base.include(InstanceMethods)
        end

        # Configurable instance behavior for integrations
        module InstanceMethods
          # Get matching configuration by matcher.
          # If no match, returns the default configuration instance.
          def configuration(matcher = :default)
            return default_configuration if matcher == :default

            resolver.get(matcher) || default_configuration
          end

          # Resolves the matching configuration for integration-specific value