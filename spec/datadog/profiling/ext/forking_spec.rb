require 'datadog/profiling/spec_helper'

require 'datadog/profiling/ext/forking'

RSpec.describe Datadog::Profiling::Ext::Forking do
  before { skip_if_profiling_not_supported(self) }

  describe '::apply!' do
    subject(:apply!) { described_class.apply! }

    let(:toplevel_receiver) { TOPLEVEL_BINDING.receiver }

    context 'when forking is supported' do
      around do |example|
        # NOTE: Do not move this to a before, since we also want to skip the around as well
        skip 'Forking not supported' unless described_class.supported?

        if ::Process.singleton_class.ancestors.include?(Datadog::Profiling::Ext::Forking::Kernel)
          skip 'Unclean Process class state.'
        end

        unmodified_process_class = ::Process.dup
        unmodified_kernel_class = ::Kernel.dup

        example.run

        # Clean up classes
        Object.send(:remove_const, :Process)
        Object.const_set('Process', unmodified_process_class)

        Object.send(:remove_const, :Kernel)
        Object.const_set('Kernel', unmodified_kernel_class)

        # Check for leaks (make sure test is properly cleaned up)
        expect(::Process <= described_class::Kernel).to be nil
        expect(::Process <= described_class::ProcessDaemonPatch).to be nil
        expect(::Kernel <= described_class::Kernel).to be nil
        # Can't assert this because top level can't be reverted; can't guarantee pristine state.
        # expect(toplevel_receiver.class.ancestors.include?(described_class::Kernel)).to be false

        expect(::Process.method(:fork).source_location).to be nil
        expect(::Kernel.method(:fork).source_location).to be nil
        expect(::Process.method(:daemon).source_location).to be nil
        # Can't assert this because top level can't be reverted; can't guarantee pristine state.
        # expect(toplevel_receiver.method(:fork).source_location).to be nil
      end

      it 'applies the Kernel patch' do
        # NOTE: There's no way to undo a modification of the TOPLEVEL_BINDING.
        #       The results of this will carry over into other tests...
        #       Just assert that the receiver was patched instead.
        #       Unfortunately means we can't test if "fork" works in main Object.

        apply!

        expect(::Process.ancestors).to include(described_class::Kernel)
        expect(::Process.ancestors).to include(described_class::ProcessDaemonPatch)
        expect(::Kernel.ancestors).to include(described_class::Kernel)
        expect(toplevel_receiver.class.ancestors).to include(described_class::Kernel)

        expect(::Process.method(:fork).source_location.first).to match(%r{.*datadog/profiling/ext/forking.rb})
        expect(::Process.method(:daemon).source_location.first).to match(%r{.*datadog/profiling/ext/forking.rb})
        expect(::Kernel.method(:fork).source_location.first).to match(%r{.*datadog/profiling/ext/forking.rb})
        expect(toplevel_receiver.method(:fork).source_location.first).to match(%r{.*datadog/profiling/ext/forking.rb})
      end
    end

    context 'when forking is not supported' do
      before do
        allow(described_class)
          .to receive(:supported?)
          .and_return(false)
      end

      it 'skips the Kernel patch' do
        is_expected.to be false
      end
    end
  end

  describe Datadog::Profiling::Ext::Forking::Kernel do
    before { skip 'Forking not supported' unless Datadog::Profiling::Ext::Forking.supported? }

    shared_context 'fork class' do
      def new_fork_class
        Class.new.tap do |c|
          c.singleton_class.class_eval do
            prepend Datadog::Profiling::Ext::Forking::Kernel

            def fork(&block)
              Kernel.fork(&block)
            end
          end
        end
      end

      subject(:fork_class) { new_fork_class }

      let(:fork_result) { :fork_result }

      before do
        # Stub out actual forking, return mock result.
        # This also makes callback order deterministic.
        allow(Kernel).to receive(:fork) do |*_args, &b|
          b.call unless b.nil?
          fork_result
        en