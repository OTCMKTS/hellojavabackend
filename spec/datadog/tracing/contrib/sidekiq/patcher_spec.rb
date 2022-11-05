require 'datadog/tracing/contrib/support/spec_helper'
require_relative 'support/helper'

RSpec.describe Datadog::Tracing::Contrib::Sidekiq::Patcher do
  before do
    # Sidekiq 3.x unfortunately doesn't let us access server_middleware unless
    # actually a server, so we just have to skip them.
    skip if Gem.loaded_specs['sidekiq'].version < Gem::Version.new('4.0')

    Sidekiq.client_middleware.clear
    Sidekiq.server_middleware.clear

    allow(Sidekiq).to receive(:server?).and_return(server)

    # these are only loaded when `Sidekiq::CLI` is actually loaded,
    # which we don't want to do here because it mutates global state
    stub_const('Sidekiq::Launcher', Class.new)
    stub_const('Sidekiq::Processor', Class.new)
    stub_const('Sidekiq::Scheduled::Poller', Class.new)
    stub_const('Sidekiq::ServerInternalTracer::RedisInfo', Class.new)

    # NB: This is needed beca