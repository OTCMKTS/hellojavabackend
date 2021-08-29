# frozen_string_literal: true

module Datadog
  module AppSec
    module Contrib
      module Sinatra
        module Reactive
          # Dispatch data from a Sinatra request to the WAF context
          module Routed
            ADDRESSES = [
              'sinatra.request.route_params',
            ].freeze
            private_constant :ADDRESSES

            def self.publish(op, data