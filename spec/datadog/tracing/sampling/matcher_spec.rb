require 'spec_helper'

require 'datadog/tracing/sampling/matcher'

RSpec.describe Datadog::Tracing::Sampling::SimpleMatcher do
  let(:span_op) { Datadog::Tracing::SpanOperation.new(span_name, service: span_service) }
  let(:span_name) { 'operati