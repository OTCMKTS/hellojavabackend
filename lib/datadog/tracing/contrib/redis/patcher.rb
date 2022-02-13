require_relative '../patcher'
require_relative 'ext'
require_relative 'configuration/resolver'

module Datadog
  module Tracing
    module Contrib
      module Redis
        # Patcher enables patching of 'redis' module.
        module Patcher
          include Contrib::Patcher

          # Patch for redis instance
          module InstancePatch
            def self.included(base)
 