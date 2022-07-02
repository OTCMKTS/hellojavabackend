require 'spec_helper'

require 'datadog/profiling/pprof/message_set'

RSpec.describe Datadog::Profiling::Pprof::MessageSet do
  subject(:message_set) { described_class.new }

  it { is_