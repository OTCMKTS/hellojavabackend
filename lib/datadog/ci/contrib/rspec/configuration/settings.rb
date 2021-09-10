require_relative '../../../../tracing/contrib/configuration/settings'
require_relative '../ext'

module Datadog
  module CI
    module Contrib
      module RSpec
        module Configuration
          # Custom settings for the RSpec integration
          # TODO: mark as `@public_api` when GA
          class Settings < Datadog::Tracing::Contrib::Configuration::Settings
            option :enabled do |o|
   