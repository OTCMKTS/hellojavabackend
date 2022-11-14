require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/analytics_examples'
require 'sucker_punch'
require 'ddtrace'

RSpec.describe 'sucker_punch instrumentation' do
  before do
    Datadog.configure do |c|
      c.tracing.instrument :sucker_punch
    end

    SuckerPunch::RUNNING.make_true
  end

  after do
    count = Thread.list.size

    SuckerPunch::RUNNING.make_false
    SuckerPunch::Queue.all.each(&:shutdown)
    SuckerPunch::Queue.clear

    next unless expect_thread?

    # Unfortunately, SuckerPunch queues (which are concurrent-ruby
    # ThreadPoolExecutor instances) don't have an interface that
    # waits until threads have completely terminated.
    # Even methods like
    # http://ruby-concurrency.github.io/concurrent-ruby/1.1.8/Concurrent/ThreadPoolExecutor.html#wait_for_termination-instance_method
    # only wait until the exec