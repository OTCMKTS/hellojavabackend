require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/analytics_examples'

require 'securerandom'
require 'rake'
require 'rake/tasklib'
require 'ddtrace'
require 'datadog/tracing/contrib/rake/patcher'

RSpec.describe Datadog::Tracing::Contrib::Rake::Instrumentation do
  let(:configuration_options) { { enabled: true, tasks: instrumented_task_names } }
  let(:task_name) { :test_rake_instrumentation }
  let(:instrumented_task_names) { [task_name] }
  let(:task_body) { proc { |task, args| spy.call(task, args) } }
  let(:task_arg_names) { [] }
  let(:task_class) do
    stub_const('RakeInstrumentationTestTask', Class.new(Rake::TaskLib)).tap do |task_class|
      tb = task_body
      task_class.send(:define_method, :initialize) do |name = task_name, *args|
        task(name, *args, &tb)
      end
    end
  end
  let(:task) { Rake::Task[task_name] }
  let(:spy) { double('spy') }

  before do
    skip('Rake integration incompatible.') unless Datadog::Tracing::Contrib::Rake::Integration.compatible?

    # Reset options (that might linger from other tests)
    Datadog.configuration.tracing[:rake].reset!

    # Patch Rake
    Datadog.configure do |c|
      c.tracing.instrument :rake, configuration_options
    end
  end

  around do |example|
    # Reset before and after each example; don't allow global state to linger.
    Datadog.registry[:rake].reset_configuration!
    example.run
    Datadog.registry[:rake].reset_configuration!

    # We don't want instrumentation enabled during the rest of the test suite...
    Datadog.configure { |c| c.tracing.instrument :rake, enabled: false }
  end

  def reset_task!(task_name)
    if Rake::Task.task_defined?(task_name)
      Rake::Task[task_name].reenable
      Rake::Task[task_name].clear

      # Rake prior to version 12.0 doesn't clear args when #clear is invoked.
      # Perform a more invasive reset, to make sure its reusable.
      if Gem::Version.new(Rake::VERSION) < Gem::Version.new('12.0')
        Rake::Task[task_name].instance_variable_set(:@arg_names, nil)
      end
    end
  end

  describe '#invoke' do
    subject(:invoke) { task.invoke(*args) }

    before do
      ::Rake.application.instance_variable_set(:@top_level_tasks, [task_name.to_s])
      expect(Datadog::Tracing).to receive(:shutdown!).once.and_call_original
    end

    let(:invoke_span) { spans.find { |s| s.name == Datadog::Tracing::Contrib::Rake::Ext::SPAN_INVOKE } }
    let(:execute_span) { spans.find { |s| s.name == Datadog::Tracing::Contrib::Rake::Ext::SPAN_EXECUTE } }

    shared_examples_for 'a single task execution' do
      it 'contains invoke and execute spans' do
        expect(spans).to have(2).items
      end

      describe '\'rake.invoke\' span' do
        it do
          expect(invoke_span.name).to eq(Datadog::Tracing::Contrib::Rake::Ext::SPAN_INVOKE)
          expect(invoke_span.resource).to eq(task_name.to_s)
          expect(invoke_span.parent_id).to eq(0)
          expect(invoke_span.service).to eq(tracer.default_service)
          expect(invoke_span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT))
            .to eq('rake')
          expect(invoke_span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
            .to eq('invoke')
        end

        it_behaves_like 'analytics for integration' do
          let(:span) { invoke_span }
          let(:analytics_enabled_var) { Datadog::Tracing::Contrib::Rake::Ext::ENV_ANALYTICS_ENABLED }
          let(:analytics_sample_rate_var) { Datadog::Tracing::Contrib::Rake::Ext::ENV_ANALYTICS_SAMPLE_RATE }
        end

        it_behaves_like 'measured span for integration', true do
          let(:span) { invoke_span }
        end
      end

      describe '