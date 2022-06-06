require 'spec_helper'

require 'datadog/core/worker'
require 'datadog/core/workers/queue'

RSpec.describe Datadog::Core::Workers::Queue do
  context 'when included into a worker' do
    subject(:worker) { worker_class.new(&task) }

    let(:worker_class) do
      Class.new(Datadog::Core::Worker) { include Datadog::Core::Workers::Queue }
    end

    let(:task) 