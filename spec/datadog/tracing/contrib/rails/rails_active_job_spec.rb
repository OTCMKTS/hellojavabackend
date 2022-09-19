# This module tests the right integration between Sidekiq and
# Rails. Functionality tests for Rails and Sidekiq must go
# in their testing modules.
begin
  require 'sidekiq/testing'
  require 'datadog/tracing/contrib/sidekiq/server_tracer'
rescue LoadError
  puts 'Sidekiq testing harness not loaded'
end

begin
  require 'active_job'
rescue LoadError
  puts 'ActiveJob not supported in this version of Rails'
end

require 'datadog/tracing/contrib/rails/rails_helper'
require 'datadog/tracing/contrib/active_job/integration'

RSpec.describe 'ActiveJob' do
  before { skip unless defined? ::ActiveJob }
  after { remove_patch!(:active_job) }
  include_context 'Rails test application'

  context 'with active_job instrumentation' do
    subject(:job_class) do
      stub_const('JOB_EXECUTIONS',  Concurrent::AtomicFixnum.new(0))
      stub_const('JobDiscardError', Class.new(StandardError))
      stub_const('JobRetryError', Class.new(StandardError))

      stub_const(
        'ExampleJob',
        Class.new(ActiveJob::Base) do
          def perform(test_retry: false, test_discard: false)
            ActiveJob::Base.logger.info 'MINASWAN'
            JOB_EXECUTIONS.increment
            raise JobRetryError if test_retry
            raise JobDiscardError if test_discard
          end
        end
      )
      ExampleJob.discard_on(JobDiscardError) if ExampleJob.respond_to?(:discard_on)
      ExampleJob.retry_on(JobRetryError, attempts: 2, wait: 2) { nil } if ExampleJob.respond_to?(