require_relative '../active_support/notifications/event'

module Datadog
  module Tracing
    module Contrib
      module ActiveRecord
        # Defines basic behaviors for an ActiveRecord event.
        module Event
          def self.included(base)
            base.include(Active