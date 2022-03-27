require_relative '../../core'
require_relative '../../core/worker'
require_relative '../../core/workers/async'
require_relative '../../core/workers/polling'
require_relative '../../core/workers/queue'

require_relative '../buffer'
require_relative '../pipeline'
require_relative '../event'

require_relative '../../../ddtrace/transport/http'

module Datadog
  module Tracing
    module Workers
      # Writes traces to transport synchronously
      class TraceWriter < Core::Worker
        attr_reader \
          :transport

        # rubocop:disable Lint/MissingSuper
        def initialize(options = {})
          transport_options = options.fetch(:transport_options, {})

          transport_options[:agent_settings] = options[:agent_settings] if options.key?(:agent_settings)

          @transport = options.fetch(:transport) do
            Transport::HTTP.default(**transport_options)
          end
        end
        # rubocop:enable Lint/MissingSuper

        def perform(traces)
          write_traces(traces)
        end

        def write(trace)
          write_traces([trace])
        end

        def write_traces(traces)
          traces = process_traces(traces)
          flush_traces(traces)
        rescue StandardError => e
          Datadog.logger.error(
            "Error while writing traces: dropped #{traces.length} items. Cause: #{e} Location: #{Array(e.backtrace).first}"
          )
        end

        def process_traces(traces)
          # Run traces through the processing pipeline
          Pipeline.process!(traces)
        end

        def flush_traces(traces)
          transport.send_traces(traces).tap do |response|
            flush_completed.publish(response)
          end
        end

        # TODO: Register `Datadog::Core::Diagnostics::EnvironmentLogger.log!`
        # TODO: as a flush_completed subscriber when the `TraceWriter`
        # TODO: instantiation code is implemented.
        def flush_completed
          @flush_completed ||= FlushCompleted.new
        end

        # Flush completed event for worker
        class FlushCompleted < Event
          def initialize
            super(:flush_completed)
          end
        end
      end

      # Writes traces to transport asynchronously,
      # using a thread & buffer.
      class AsyncTraceWriter < TraceWriter
        include Core::Workers::Queue
        include Core::Workers::Polling

        DEFAULT_BUFFER_MAX_SIZE = 1000
        FORK_POLICY_ASYNC = :async
        FORK_POLICY_SYNC = :sync

        attr_writer \
          :async

        def initialize(options = {})
          # Workers::TraceWriter settings
          super

          # Workers::Polling settings
          self.enabled = options.fetch(:enabled, true)

          # Workers::Async::Thread settings
          @async = true
          self.fork_policy = options.fetch(:fork_policy, FORK_POLICY_ASYNC)

          # Workers::IntervalLoop settings
          self.loop_base_interval = options[:interval] if options.key?(:interval)
          self.loop_back_off_ratio = options[:back_off_ratio] if options.key?(:back_off_ratio)
          self.loop_back_off_max = options[:back_off_max] if options.key?(:back_off_max)

          # Workers::Queue settings
          @buffer_size = options.fetch(:buffer_size, DEFAULT_BUFFER_MAX_SIZE)
          self.buffer = TraceBuffer.new(@buffer_size)
        end

        # NOTE: #perform is wrapped by other modules:
        #       Polling --> Async --> IntervalLoop --> AsyncTraceWriter --> TraceWriter
        #
        # WARNING: This method breaks the Liskov Substitution Principle -- TraceWriter#perform is spec'd to return the
        # result from the writer, whereas this metho