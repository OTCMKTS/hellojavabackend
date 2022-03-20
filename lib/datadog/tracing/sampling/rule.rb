require_relative '../../core'

require_relative 'matcher'
require_relative 'rate_sampler'

module Datadog
  module Tracing
    module Sampling
      # Sampling rule that dictates if a trace matches
      # a specific criteria and what sampling strategy to
      # apply in case of a positive match.
      # @public_api
      class Rule
        attr_reader :matcher, :sampler

        # @param [Matcher] matcher A matcher to verify trace conformity against
        # @param [Sampler] sampler A sampler to be consulted on a positive match
        def initialize(matcher, sampler)
          @m