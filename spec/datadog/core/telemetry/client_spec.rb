require 'spec_helper'

require 'datadog/core/telemetry/client'

RSpec.describe Datadog::Core::Telemetry::Client do
  subject(:client) { described_class.new(enabled: enabled) }
  let(:enabled) { true }
  let(:emitter) { double(Datadog::Core::Telemetry::Emitter) }
  let(:response) { double(Datadog::Core::Telemetry::Http::Adapters::Net::Response) }
  let(:not_found) { false }

  before do
    allow(Datadog::Core::Telemetry::Emitter).to receive(:new).and_return(emitter)
    allow(emitter).to receive(:request).and_return(response)
    allow(response).to receive(:not_found?).and_return(not_found)
  end

  describe '#initialize' do
    after do
      client.worker.stop(true)
      client.worker.join
 