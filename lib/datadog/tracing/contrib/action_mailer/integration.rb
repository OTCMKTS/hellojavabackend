require_relative 'configuration/settings'
require_relative 'patcher'
require_relative '../integration'
require_relative '../rails/utils'

module Datadog
  module Tracing
    module Contrib
      module ActionMailer
        # Description of ActionMailer integration
        class In