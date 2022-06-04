require 'spec_helper'

require 'datadog/core/telemetry/http/response'

RSpec.describe Datadog::Core::Telemetry::Http::Response do
  context 'when implemented by a class' do
    subject(:response) { response_class.new }

    let(:response_class) do
      stub_const('TestResponse', Class.new { include Datadog::Core::Telemetry::Http::Response })
    end

    describe '#