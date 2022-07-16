require 'logger'

require 'datadog/tracing'
require 'datadog/tracing/metadata/ext'
require 'datadog/tracing/contrib/action_cable/ext'
require 'datadog/tracing/contrib/action_cable/events/broadcast'

require 'datadog/tracing/contrib/rails/rails_helper'
require 'datadog/tracing/contrib/analytics_examples'
require 'datadog/tracing/contrib/support/spec_helper'
require 'spec/datadog/tracing/contrib/rails/support/deprecation'

begin
  require 'action_cable'
rescue LoadError
  puts 'ActionCable not supported in Rails < 5.0'
end

RSpec.describe 'ActionCable patcher' do
  before { skip('ActionCable not supported') unless Datadog::Tracing::Contrib::ActionCable::Integration.compatible? }

  let(:configuration_options) { {} }
  let(:span) do
    expect(spans).to have(1).item
    spans.first
  end

  before do
    Datadog.configure do |c|
      c.tracing.instrument :action_cable, configuration_options
    end

    raise_on_rails_deprecation!
  end

  around do |example|
   