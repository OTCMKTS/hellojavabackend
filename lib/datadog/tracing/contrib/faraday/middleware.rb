require 'faraday'

require_relative '../../metadata/ext'
require_relative '../../propagation/http'
require_relative '../analytics'
require_relative 'ext'
require_relative '../http_annotation_helper'

module Datadog
  module Tracing
    module Contrib
      module Faraday
        # Middleware implements a faraday-middleware for ddtrace instrumentation
        class Middleware < ::Faraday::Middleware
          include Contrib::HttpAnnotationHelper

          def initialize(app, options = {})
            super(app)
            @options = options
          end

          def call(env)
            # Resolve configuration settings to use for this request.
            # Do this once to reduce expensive regex calls.
            request_options = build_request_options!(env)

            Tracing.trace(Ext::SPAN_REQUEST) do |span, trace|
              annotate!(span, env, request_options)
              propagate!(trace, span, env) if request_options[:distributed_tracing] && Tracing.enabled?
              app.call(env).on_complete { |resp| hand