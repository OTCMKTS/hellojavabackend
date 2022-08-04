require 'ddtrace'
require 'mongo'

RSpec.describe 'Mongo crash regression #1235' do
  before { skip unless PlatformHelpers.mri? }

  let(:client) { Mongo::Client.new(["#{host}:#{port}"], client_options) }
  let(:client_options) { { database: database } }
  let(:host) { ENV.fetch('TEST_MONGODB_HOST', '127.0.0.1') }
  let(:port) { ENV.fetch('TEST_MONGODB_PORT', 27017).to_i }
  let(:database) { 'test' }

  before do
    # Disable Mongo logging
    Mongo::Logger.logger.level = ::Logger::WARN

    Datadog.configure do |c|
      c.tracing.instrument :mongo
    end
  end

  subject do
