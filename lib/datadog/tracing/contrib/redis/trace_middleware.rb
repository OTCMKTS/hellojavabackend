require_relative '../patcher'
require_relative 'ext'
require_relative 'quantize'
require_relative 'tags'

module Datadog
  module Tracing
    module Contrib
      module Redis
        # Instrumentation for Re