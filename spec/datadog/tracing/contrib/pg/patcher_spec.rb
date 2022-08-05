require 'datadog/tracing/contrib/integration_examples'
require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/analytics_examples'
require 'datadog/tracing/contrib/sql_comment_propagation_examples'
require 'datadog/tracing/contrib/environment_service_name_examples'

require 'datadog/tracing/contrib/propagation/sql_comment/mode'

require 'ddtrace'
require 'pg'

RSpec.describe 'PG::Connection patcher' do
  let(:service_name) { 'pg' }
  let(:configuration_options) { { service_name: service_name } }

  let(:conn) do
    PG::Connection.new(
      host: host,
      port: port,
      dbname: dbname,
      user: user,
      password: password
    )
  end

  let(:host) { ENV.fetch('TEST_POSTGRES_HOST') { '127.0.0.1' } }
  let(:port) { ENV.fetch('TEST_POSTGRES_PORT') { '5432' } }
  let(:dbname) { ENV.fetch('TEST_POSTGRES_DB') { 'postgres' } }
  let(:user) { ENV.fetch('TEST_POSTGRES_USER') { 'postgres' } }
  let(:password) { ENV.fetch('TEST_POSTGRES_PASSWORD') { 'postgres' } }

  before do
    Datadog.configure do |c|
      c.tracing.instrument :pg, configuration_options
    end
  end

  around do |example|
    # Reset before and after each example; don't allow global state to linger.
    Datadog.registry[:pg].reset_configuration!
    example.run
    Datadog.registry[:pg].reset_configuration!
  end

  after do
    conn.close
  end

  describe 'tracing' do
    describe '#exec' do
      let(:sql_statement) { 'SELECT 1;' }

      context 'when without a given block' do
        subject(:exec) { conn.exec(sql_statement) }

        context 'when the tracer is disabled' do
          before { tracer.enabled = false }

          it 'does not write spans' do
            exec

            expect(spans).to be_empty
          end
        end

        context 'when the tracer is configured directly' do
          let(:service_name) { 'pg-override' }

          before { Datadog.configure_onto(conn, service_name: service_name) }

          it_behaves_like 'with sql comment propagation', span_op_name: 'pg.exec'

          it 'produces a trace with service override' do
            exec

            expect(spans.count).to eq(1)
            expect(span.service).to eq(service_name)
            expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_PEER_SERVICE)).to eq(service_name)
          end
        end

        context 'when a successful query is made' do
          it_behaves_like 'with sql comment propagation', span_op_name: 'pg.exec'

          it 'produces a trace' do
            ex