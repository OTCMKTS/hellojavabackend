require_relative '../../configuration/settings'
require_relative '../ext'

module Datadog
  module Tracing
    module Contrib
      module RestClient
        module Configuration
          # Custom settings for the RestClient integration
          # @public_api
          class Settings < Contrib::Configuration::Set