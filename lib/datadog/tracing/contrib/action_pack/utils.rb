require_relative '../analytics'

module Datadog
  module Tracing
    module Contrib
      module ActionPack
        # Common utilities for ActionPack
        module Utils
          def self.exception_is_error?(exception)
            if defined?(::ActionDispatch::ExceptionWrapper)
              # Gets the equi