require 'spec_helper'

require 'ddtrace/transport/http/adapters/unix_socket'

RSpec.describe Datadog::Transport::HTTP::Adapters::UnixSocket do
  subject(:adapter) { described_class.new(uds_path, **options) }

  let(:uds_path) { double('uds_path') }
  let(:timeout) { double('timeout') }
  let(:options) { { timeout: timeout } }

  shared_context 'HTTP connection stub' d