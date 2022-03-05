require 'set'

require_relative '../../core'
require_relative '../metadata/ext'

module Datadog
  module Tracing
    module Contrib
      # Contains methods helpful for tracing/annotating HTTP request libraries
      class StatusCodeMatcher
        REGEX_PARSER = /^\d{3}(?:-\d{3})?(?:,\d{3}(?:-\d{3})?)*$/.freeze

        def initialize(range)
      