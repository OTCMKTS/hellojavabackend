require 'datadog/tracing/metadata/ext'

RSpec.shared_examples_for 'analytics for integration' do |options = { ignore_global_flag: true }|
  around do |example|
    # Reset before and after each example; don't allow global state to linger.
    without_warnings { Datadog.configuration.reset! }
    example.run
    without_warnings { Datadog.configuration.reset! }
  end

  context 'when not configured' do
    context 'and the global flag is not set' do
      it 'is not included in the tags' do
        expect(span.get_metric(Datadog::Tracing::Metadata::Ext::Analytics::TAG_SAMPLE_RATE)).to be nil
      end
    end

    context 'and the global flag is enabled' do
      around do |example|
        ClimateControl.modify(Datadog::Tracing::Configuration::Ext::Analytics::ENV_TRACE_ANALYTICS_ENABLED => 'true') do
          example.run
        end
      end

      # Most 