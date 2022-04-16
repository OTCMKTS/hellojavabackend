require 'datadog/appsec/spec_helper'

RSpec.describe Datadog::AppSec::Extensions do
  shared_context 'registry with integration' do
    let(:registry) { {} }
    let(:integration_name) { :example }
    let(:integration_options) { double('integration integration_options') }
    let(:integration_class) { double('integration class', loaded?: false) }
    let(:integration) do
      instance_double(
        Datadog::AppSec::Contrib::Integration::RegisteredIntegration,
        klass: integration_class,
        options: integration_options
      )
    end

    before do
      registry[integration_name] = integration

      allow(Datadog::AppSec::Contrib::Integration).to receive(:registry).and_return(registry)
    end
  end

  context 'for' do
    describe Datadog do
      after { described_class.configuration.appsec.send(:reset!) }
      describe '#configure' do
        include_context 'registry with integration'

        context 'given a block' do
          subject(:configure) { described_class.configure(&block) }

          context 'that calls #instrument for an integration' do
            let(:block) { proc { |c| c.appsec.instrument integration_name } }

            it 'configures the integration' do
              # If integration_class.loaded? is invoked, it means the correct integration is being activated.
              begin
                old_appsec_enabled = ENV['DD_APPSEC_ENABLED']
                ENV['DD_APPSEC_ENABLED'] = 'true'
                expect(integration_class).to receive(