require_relative '../response'

module Datadog
  module Transport
    module HTTP
      # Wraps an HTTP response from an adapter.
      #
      # Used by endpoints to wrap