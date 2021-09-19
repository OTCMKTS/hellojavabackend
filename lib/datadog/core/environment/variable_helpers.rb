module Datadog
  module Core
    # Namespace for handling application environment
    module Environment
      # Defines helper methods for environment
      # @public_api
      module VariableHelpers
        extend self

        # Reads an environment variable as a Boolean.
        #
        # @param [String] var environment variable
        # @param [Array<String>] var list of environment variables
        # @param [Boolean] default the default value if the keys in `var` are not present in the environment
        # @param [Boolean] deprecation_warning when `var` is a list, record a deprecation log when
        #   the first key in `var` is not used.
        # @return [Boolean] if the environment value is the string `true`
        # @return [default] if the environment value is not found
        def env_to_bool(var, default = nil, deprecation_warning: true)
          var = decode_array(var, deprecation_warning)
          var && ENV.key?(var) ? ENV[var].to_s.strip.downcase == 'true' : default
        end

        # Reads an environment variable as an Integer.
        #
        # @param [String] var environment variable
        # @param [Array<String>] var list of environment variables
        # @param [Integer] default the default value if the keys in `var` are not present in the environment
        # @param [Boolean] deprecation_warning when `var` is a list, record a deprecation log when
        #   the first key in `var` is not used.
        # @return [Integer] if the environment value is a valid Integer
        # @return [default] if the environment value is not found
        def env_to_int(var, default = nil, deprecation_warning: true)
          var = decode_array(var, deprecation_warning)
          var && ENV.key?(var) ? ENV[var].to_i : default
        end

        # Reads an environment variable as a Float.
        #
        # @param [String] var environment variable
        # @param [Array<String>] var list of environment variables
        # @param [Float] default the default value if the keys in `var` are not pres