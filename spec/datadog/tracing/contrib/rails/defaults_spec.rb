
require 'datadog/tracing/contrib/rails/rails_helper'

RSpec.describe 'Rails defaults' do
  include_context 'Rails test application'

  context 'when Datadog.configuration.service' do
    after { without_warnings { Datadog.configuration.reset! } }

    context 'is not configured' do
      before { app }
