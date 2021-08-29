# frozen_string_literal: true

require_relative '../../ext'
require_relative '../../instrumentation/gateway'
require_relative '../../reactive/operation'
require_relative '../reactive/set_user'

module Datadog
  module AppSec
    module Monitor
      module Gateway
        # Watcher for Apssec internal events
        module Watcher
          class << self
            def watch
              gateway = Instrumentation.gateway

              watch_user_id(gateway)
            end

            def watch_user_id(gateway = Instrumentation.gateway)
              gateway.watch('identity.set_user', :appsec) do |stack, user|
                block = false
                event = nil
                waf_context = Datadog::AppSec::Processor.active_context

                AppSec::Reactive::Operation.new('identity.set_user') do |op|
                  trace = active_trace
                  span = active_span

                  Monitor::Reactive::SetUser.subscribe(op, waf_context) do |result, _block|
                    if result.status == :match
                      # TODO: should this hash be an Event instance instead?
                      event = {
                        waf_result: result,
                        trace: trace,
                        span: span,
                        user: user,
                        actions: result.actions
                      }

                      span.set_tag('appsec.event', 'true') if span

                      waf_context.events << event
                    end
                  end

                  _result, block = Monitor::Reactive::SetUser.publish(op, user)
                end

                throw(Datadog::AppSec::Ext::INTERRUPT, [nil, [:block, event]]) if block

                