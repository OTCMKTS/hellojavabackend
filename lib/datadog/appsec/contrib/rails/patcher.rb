require_relative '../../../core/utils/only_once'

require_relative '../patcher'
require_relative 'framework'
require_relative '../../response'
require_relative '../rack/request_middleware'
require_relative '../rack/request_body_middleware'
require_relative 'gateway/watcher'
require_relative 'gateway/request'

require_relative '../../../tracing/contrib/rack/middlewares'

module Datadog
  module AppSec
    module Contrib
      module Rails
        # Patcher for AppSec on Rails
        module Patcher
          include Datadog::AppSec::Contrib::Patcher

          BEFORE_INITIALIZE_ONLY_ONCE_PER_APP = Hash.new { |h, key| h[key] = Datadog::Core::Utils::OnlyOnce.new }
          AFTER_INITIALIZE_ONLY_ONCE_PER_APP = Hash.new { |h, key| h[key] = Datadog::Core::Utils::OnlyOnce.new }

          module_function

          def patched?
            Patcher.instance_variable_get(:@patched)
          end

          def target_version
            Integration.version
          end

          def patch
            Gateway::Watcher.watch
            patch_before_intialize
            patch_after_intialize

            Patcher.instance_variable_set(:@patched, true)
          end

          def patch_before_intialize
            ::ActiveSupport.on_load(:before_initialize) do
              Datadog::AppSec::Contrib::Rails::Patcher.before_intialize(self)
            end
          end

          def before_intialize(app)
            BEFORE_INITIALIZE_ONLY_ONCE_PER_APP[app].run do
              # Middleware must be added before the application is initialized.
              # Otherwise the middleware stack will be frozen.
              # Sometimes we don't want to activate middleware e.g. OpenTracing, etc.
              add_middleware(app) if Datadog.configuration.tracing[:rails][:middleware]
              patch_process_action
            end
          end

          def add_middleware(app)
            # Add trace middleware
            if include_middleware?(Datadog::Tracing::Contrib::Rack::TraceMiddleware, app)
              app.middleware.insert_after(
                Datadog::Tracing::Contrib::Rack::TraceMiddleware,
                Datadog::AppSec::Contrib::Rack::RequestMiddlew