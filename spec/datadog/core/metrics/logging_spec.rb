require 'spec_helper'

require 'logger'
require 'json'

require 'datadog/core/metrics/logging'
require 'datadog/core/metrics/client'

RSpec.describe Datadog::Core::Metrics::Logging::Adapter do
  subject(:adapter) { described_class.new(logger) }

  let(:logger) { instance_double(Logger) }

  def have_received_json_metric(expected_hash)
    have_received(:info) do |msg|
      json = JSON.parse(msg)
      expect(json).to include('stat' => expected_hash[:stat])
      expect(json).to include('type' => expected_hash[:type])
      expect(json).to include('value' => expected_hash[:value]) if expected_hash.key?(:value)
      expect(json).to include('options' => hash_including(expected_hash[:options]))
    end
  end

  describe '#initialize' do
    context 'by de