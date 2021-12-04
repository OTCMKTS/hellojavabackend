module Datadog
  module Tracing
    module Contrib
      module Configuration
        # Resolves an integration-specific matcher to an associated
        # object.
        #
        # Integrations that perform any configuration matching
        # based on patterns might want to override this class
        # to provide richer matching. For example, match configuration
        # based on: HTTP request parameters, request headers,
        # async queue name.
        #
        # When overriding this class, for simple use cases, only
        # overriding `#parse_matcher` might suffice. See
        # `#parse_matcher`'s documentation for more information.
        class Resolver
          attr_reader :configurations

          def initialize
            @configurations = {}
          end

          # Adds a new `matcher`, associating with it a `value`.
          #
          # This `value` is returned when `#resolve` is called
          # with a matching value for this matcher. When multiple
          # matchers would match, `#resolve` returns the latest
          # added one.
          #
          # The `matcher` can be transformed internally by the
          # `#parse_matcher` method before being stored.
          #
          # The `value` can also be retrieved by calling `#get`
          # with the same `matcher` added by this method.
          #
          # @param [Object] matcher integration-specific matcher
          # @param [Object] value arbitrary value to be associated with `matcher`
          def add(matcher, value)
            @configurations[parse_matcher(matcher)] = value
          end

          # Retrieves the stored value for a `matcher`
          # previously stored by `#add`.
          #
          # @param [Object] matcher integration-specific matcher
          # @return [Object] previous