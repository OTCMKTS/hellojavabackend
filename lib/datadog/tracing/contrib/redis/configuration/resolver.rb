require_relative '../vendor/resolver'

module Datadog
  module Tracing
    module Contrib
      module Redis
        module Configuration
          UNIX_SCHEME = 'unix'.freeze

          # Converts String URLs and Hashes to a normalized connection settings Hash.
          class Resolver < Contrib::Configuration::Resolver
            # @param [Hash,String] Redis connection information
            def resolve(hash)
              super(parse_matcher(has