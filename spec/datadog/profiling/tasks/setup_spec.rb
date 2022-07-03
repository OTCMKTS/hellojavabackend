require 'spec_helper'
require 'datadog/profiling/spec_helper'

require 'datadog/profiling'
require 'datadog/profiling/tasks/setup'
require 'datadog/profiling/ext/forking'

RSpec.describe Datadog::Profiling::Tasks::Setup do
  subject(:task) { described_class.new }

  describe '#run' do
    subject(:run) { task.run }

    before do
      described_class::ACTIVATE_EXTENSIONS_ONLY_ONCE.send(:reset_ran_once_state_for_tests)

      allow(task).to receive(:check_if_cpu_time_profiling_is_supported)
    end

    it 'actives the forking extension before setting up the at_fork hooks' do
      expect(task).to receive(:activate_forking_extensions).ordered
      expect(task).to receive(:setup_at_fork_hooks).ordered

      run
    end

    it 'checks if CPU time profiling is available' do
      expect(task).to receive(:check_if_cpu_time_profiling_is_supported)

      run
    end

    it 'only sets up the extensions and hooks once, even across different instances' do
      expect_any_instance_of(described_class).to receive(:activate_forking_extensions).once
      expect_any_instance_of(described_class).to receive(: