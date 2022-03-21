# frozen_string_literal: true

require_relative 'ext'

module Datadog
  module Tracing
    module Sampling
      module Span
        # Span sampling rule that applies a sampling rate if the span
        # matches the provided {Matcher}.
        # Additionally, a rate limiter is also applied.
        #
        # If a span does not conform to the matcher, no changes are made.
        class Rule
          attr_reader :matcher, :sample_rate, :rate_limit

          # Creates a new span sampling rule.
          #
          # @param [Sampling::Span::Matcher] matcher whether this rule applies to a specific span
          # @param [Float] sample_rate span sampling ratio, between 0.0 (0%) and 1.0 (100%).
          # @param [Numeric] rat