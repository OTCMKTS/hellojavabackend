require_relative '../../../tracing/contrib/rack/middlewares'

require_relative '../patcher'
require_relative '../../response'
require_relative '../rack/request_middleware'
require_relative 'framework'
require_relative 'gateway/watcher'
require_relative 'gateway/route_params'
require_relative 'gateway/request'
require_relative '../../../tracing/contrib/sinatra/framework'

module Datadog
  module AppSec
    module Contrib
      module Sinatra
        # Set tracer configuration at a late enough time
        module AppSecSetupPatch
          def setup_middleware(*args, &block)
            super.tap do
              Datadog::AppSec::Contrib::Sinatra::Framework.setup
            end
          end
        end

        # Hook into builder before the middleware list gets frozen
        module DefaultMiddlewarePatch
          def setup_middleware(*args, &block)
            builder = args.first

            super.tap do
              tracing_sinatra_framework = Datadog::Tracing::Contrib::Sinatra::Framework
              tracing_middleware = Datadog::Tracing::Contrib::R