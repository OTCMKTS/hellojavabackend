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
      ExampleJob.retry_on(JobRetryError, attempts: 2, wait: 2) { nil } if ExampleJob.respond_to?(:retry_on)

      ExampleJob
    end

    before do
      Datadog.configure do |c|
        c.tracing.instrument :active_job
      end

      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('USE_TAGGED_LOGGING').and_return(true)

      # initialize the application
      app

      # Override inline adapter to execute scheduled jobs for testingrails_active_job_spec
      if ActiveJob::QueueAdapters::InlineAdapter.respond_to?(:enqueue_at)
        allow(ActiveJob::QueueAdapters::InlineAdapter)
          .to receive(:enqueue_at) do |job, _timestamp, *job_args|
            ActiveJob::QueueAdapters::InlineAdapter.enqueue(job, *job_args)
          end
      else
        allow_any_instance_of(ActiveJob::QueueAdapters::InlineAdapter)
          .to receive(:enqueue_at) do |adapter, job, _timestamp|
            adapter.enqueue(job)
          end
      end
    end

    it 'instruments enqueue' do
      job_class.set(queue: :mice, priority: -10).perform_later

      span = spans.find { |s| s.name == 'active_job.enqueue' }
      expect(span.name).to eq('active_job.enqueue')
      expect(span.resource).to eq('ExampleJob')
      expect(span.get_tag('active_job.adapter')).to eq('ActiveJob::QueueAdapters::InlineAdapter')
      expect(span.get_tag('active_job.job.id')).to match(/[0-9a-f\-]{32}/)
      expect(span.get_tag('active_job.job.queue')).to eq('mice')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
        .to eq('active_job')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
        .to eq('enqueue')

      if Datadog::Tracing::Contrib::ActiveJob::Integration.version >= Gem::Version.new('5.0')
        expect(span.get_tag('active_job.job.priority')).to eq(-10)
      end
    end

    it 'instruments enqueue_at under the "enqueue" span' do
      scheduled_at = 1.minute.from_now
      job_class.set(queue: :mice, priority: -10, wait_until: scheduled_at).perform_later

      span = spans.find { |s| s.name == 'active_job.enqueue' }
      expect(span.name).to eq('active_job.enqueue')
      expect(span.resource).to eq('ExampleJob')
      expect(span.get_tag('active_job.adapter')).to eq('ActiveJob::QueueAdapters::InlineAdapter')
      expect(span.get_tag('active_job.job.id')).to match(/[0-9a-f\-]{32}/)
      expect(span.get_tag('active_job.job.queue')).to eq('mice')
      expect(span.get_tag('active_job.job.scheduled_at').to_time).to be_within(1).of(scheduled_at)
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
        .to eq('active_job')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
        .to eq('enqueue_at')

      if Datadog::Tracing::Contrib::ActiveJob::Integration.version >= Gem::Version.new('5.0')
        expect(span.get_tag('active_job.job.priority')).to eq(-10)
      end
    end

    it 'instruments perform' do
      job_class.set(queue: :elephants, priority: -10).perform_later

      span = spans.find { |s| s.name == 'active_job.perform' }
      expect(span.name).to eq('active_job.perform')
      expect(span.resource).to eq('ExampleJob')
      expect(span.get_tag('active_job.adapter')).to eq('ActiveJob::QueueAdapters::InlineAdapter')
      expect(span.get_tag('active_job.job.id')).to match(/[0-9a-f\-]{32}/)
      expect(span.get_tag('active_job.job.queue')).to eq('elephants')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
        .to eq('active_job')
      expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
        .to eq('perform')

      if Datadog::Tracing::Contrib::ActiveJob::Integration.version >= Gem::Version.new('5.0')
        expect(span.get_tag('active_job.job.priority')).to eq(-10)
      end
    end

    it 'instruments active_job.enqueue_retry and active_job.retry_stopped' do
      unless Datadog::Tracing::Contrib::ActiveJob::Integration.version >= Gem::Version.new('6.0')
        skip('ActiveSupport instrumentation for Retry introduced in Rails 6')
      end

      job_class.set(queue: :elephants, priority: -10).perform_later(test_retry: true)

      enqueue_retry_span = spans.find { |s| s.name == 'active_job.enqueue_retry' }
      expect(enqueue_retry_span.name).to eq('active_job.enqueue_retry')
      expect(enqueue_retry_span.resource).to eq('ExampleJob')
      expect(enqueue_retry_span.get_tag('active_job.adapter')).to eq('ActiveJob::QueueAdapters::InlineAdapter')
      expect(enqueue_retry_span.get_tag('active_job.job.id')).to match(/[0-9a-f\-]{32}/)
      expect(enqueue_retry_span.get