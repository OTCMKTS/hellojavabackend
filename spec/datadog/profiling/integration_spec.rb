require 'spec_helper'
require 'datadog/profiling/spec_helper'

require 'datadog/tracing'
require 'datadog/core/utils/time'
require 'datadog/profiling'

RSpec.describe 'profiling integration test' do
  before do
    skip_if_profiling_not_supported(self)

    raise "Profiling did not load: #{Datadog::Profiling.unsupported_reason}" unless Datadog::Profiling.supported?
  end

  let(:tracer) { instance_double(Datadog::Tracing::Tracer) }

  shared_context 'StackSample events' do
    # NOTE: Please do not convert stack_one or stack_two to let, because
    # we want the method names on the resulting stacks to be stack_one or
    # stack_two, not block in ... when showing up in the stack traces
    def stack_one
      @stack_one ||= Array(Thread.current.backtrace_locations)[1..3]
    end

    def stack_two
      @stack_two ||= Array(Thread.current.backtrace_locations)[1..3]
    end

    let(:root_span_id) { 0 }
    let(:span_id) { 0 }
    let(:trace_resource) { nil }

    let(:stack_samples) do
      [
        build_stack_sample(
          locations: stack_one,
          thread_id: 100,
          root_span_id: root_span_id,
          span_id: span_id,
          trace_resource: trace_resource,
          cpu_time_ns: 100
        ),
        build_stack_sample(
          locations: stack_two,
          thread_id: 100,
          root_span_id: root_span_id,
          span_id: span_id,
          trace_resource: trace_resource,
          cpu_time_ns: 200
        ),
        build_stack_sample(
          locations: stack_one,
          thread_id: 101,
          root_span_id: root_span_id,
          span_id: span_id,
          trace_resource: trace_resource,
          cpu_time_ns: 400
        ),
        build_stack_sample(
          locations: stack_two,
          thread_id: 101,
          root_span_id: root_span_id,
          span_id: span_id,
          trace_resource: trace_resource,
          cpu_time_ns: 800
        ),
        build_stack_sample(
          locations: stack_two,
          thread_id: 101,
          root_span_id: root_span_id,
          span_id: span_id,
          trace_resource: trace_resource,
          cpu_time_ns: 1600
        )
      ]
    end

    before do
      expect(stack_one).to_not eq(stack_two)
    end
  end

  describe 'profiling' do
    let(:old_recorder) do
      Datadog::Profiling::OldRecorder.new(
        [Datadog::Profiling::Events::StackSample],
        100000,
        last_flush_time: Time.now.utc - 5
      )
    end
    let(:exporter) { Datadog::Profiling::Exporter.new(pprof_recorder: old_recorder, code_provenance_collector: nil) }
    let(:collector) do
      Datadog::Profiling::Collectors::OldStack.new(
        old_recorder,
        trace_identifiers_helper:
          Datadog::Profiling::TraceIdentifiers::Helper.new(
            tracer: tracer,
            endpoint_collection_enabled: true
          ),
        max_frames: 400
      )
    end
    let(:transport) { instance_double(Datadog::Profiling::HttpTransport) }
    let(:scheduler) { Datadog::Profiling::Scheduler.new(exporter: exporter, transport: transport) }

    it 'produces a profile' do
      expect(transport).to receive(:export)

      collector.collect_events
      scheduler.send(:flush_events)
    end

    context 'with tracing' do
      around do |example|
        Datadog.configure do |c|
          c.diagnostics.startup_logs.enabled = false
          c.tracing.transport_options = proc { |t| t.adapter :test }
        end

        Datadog::Tracing.trace('profiler.test') do |span, trace|
          @current_span = span
          @current_root_span = trace.send(:root_span)
          example.run
        end

        Datadog::Tracing.shutdown!
        Datadog.configuration.reset!
      end

      let(:tracer) { Datadog::Tracing.send(:tracer) }

      before do
        expect(Datadog::Profiling::Encoding::Profile::Protobuf)
          .to receive(:encode)
          .and_wrap_original do |m, **args|
            encoded_pprof = m.call(**args)

            event_groups = args.fetch(:event_groups)

            # Verify that all the stack samples for this test received the same non-zero trace and span ID
            stack_sample_group = event_groups.find { |g| g.event_class == Datadog::Profiling::Events::StackSample }
            stack_samples = stack_sample_group.events.select { |e| e.thread_id == Thread.current.object_id }

            raise 'No stack samples matching current thread!' if stack_samples.empty?

            stack_samples.each do |stack_sample|
              expect(stack_sample.root_span_id).to eq(@current_root_span.span_id)
              expect(stack_sample.span_id).to eq(@current_span.span_id)
            end

            encoded_pprof
          end
      end

      it 'produces a profile including tracing data' do
        expect(transport).to receive(:export)

        collector.collect_events
        scheduler.send(:flush_events)
      end
    end
  end

  describe 'building a Perftools::Profiles::Profile using Pprof::Template' do
    subject(:build_profile) { template.to_pprof(start: start, finish: finish) }

    let(:template) {