require 'datadog/tracing/contrib/support/spec_helper'
require 'rack/test'

require 'rack'
require 'ddtrace'
require 'datadog/tracing/contrib/rack/middlewares'

RSpec.describe 'Rack integration with other middleware' do
  include Rack::Test::Methods

  let(:rack_options) do
    {
      application: app,
      middleware_names: true
    }
  end

  before do
    # Undo the Rack middleware name 