require_relative '../analytics'
require_relative '../patcher'

module Datadog
  module Tracing
    module Contrib
      module GraphQL
        # Provides instrumentation for `graphql` through the GraphQL tracing framework
        module Patcher
          include Contrib::Patcher

          module_function

          def target_version
            Integration.version
          end

          def patch
            if (schemas = get_option(:schemas))
              schemas.each { |s| patch_schema!(s) }
            end

            patch_legacy_gem!
          end

        