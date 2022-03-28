module Datadog
  module Transport
    # @public_api
    module Ext
      # @public_api
      module HTTP
        ADAPTER = :net_http # DEV: Rename to simply `:http`, as Net::HTTP is an implementation detail.
        DEFAULT_HOST = '127.0.0.1'.freeze
        DEFAULT_PORT = 8126

        HEADER_CONTAINER_ID = 'Datadog-Container-ID'.freeze
        HEADER_DD_API_KEY = 'DD-API-KEY'.freeze
        # Tells agent that `_dd.top_level` metrics have been set by the tracer.
        # The agent will not calculate top-level spans but instead trust the tracer tagging.
        #
        # This pre