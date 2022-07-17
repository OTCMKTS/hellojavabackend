require 'datadog/tracing/contrib/support/spec_helper'
require 'datadog/tracing/contrib/analytics_examples'
require 'rails'
require 'active_support'
require 'spec/datadog/tracing/contrib/action_mailer/helpers'
require 'datadog/tracing/contrib/action_mailer/integration'
require 'ddtrace'

begin
  require 'action_mailer'
rescue LoadError
  puts 'ActionCable not supported in Rails < 5.0'
end

RSpec.describe 'ActionMailer patcher' do
  include_context 'ActionMailer helpers'

  let(:configuration_options) { {} }

  before do
    if Datadog::Tracing::Contrib::ActionMailer::Integration.compatible?
      Datadog.configure do |c|
        c.tracing.instrument :action_mailer, configuration_options
      end
    else
      skip
    end
  end

  around do |example|
    # Reset before and after each example; don't allow global state to linger.
    Datadog.registry[:action_mailer].reset_configuration!
    example.run
    Datadog.registry[:action_mailer].reset_configuration!
  end

  describe 'for single process.action_mailer process' do
    let(:mailer) { 'UserMailer' }
    let(:action) { 'test_mail' }
    let(:args) do
      []
    end

    let(:span) do
      spans.find { |s| s.name == Datadog::Tracing::Contrib::ActionMailer::Ext::SPAN_PROCESS }
    end

    let(:deliver_span) do
      spans.find { |s| s.name == Datadog::Tracing::Contrib::ActionMailer::Ext::SPAN_DELIVER }
    end

    before do
      UserMailer.test_mail(1).deliver_now
    end

    context 'that doesn\'t raise an error' do
      it 'is expected to send a process span' do
        expect(span).to_not be nil
        expect(span.service).to eq(tracer.default_service)
        expect(span.name).to eq('action_mailer.process')
        expect(span.resource).to eq(mailer)
        expect(span.get_tag('action_mailer.action')).to eq(action)
        expect(span.get_tag('action_mailer.mailer')).to eq(mailer)
        expect(span.span_type).to eq('template')
        expect(span.status).to_not eq(Datadog::Tracing::Metadata::Ext::Errors::STATUS)
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_COMPONENT)).to eq('action_mailer')
        expect(span.get_tag(Datadog::Tracing::Metadata::Ext::TAG_OPERATION))
          .to eq('process')
      end

      it 'is expected to send a deliver span' do
        expect(deliver_span).to_not be nil
        expect(deliver_sp