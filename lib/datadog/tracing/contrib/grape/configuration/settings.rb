require_relative '../../configuration/settings'
require_relative '../ext'
require_relative '../../status_code_matcher'

module Datadog
  module Tracing
    module Contrib
      module Grape
        module Configuration
          # Custom settings for the Grape integration
          # @public_api
          class Settings < Contrib::Configuration::Settings
            option :enabled do |o|
              o.default { e