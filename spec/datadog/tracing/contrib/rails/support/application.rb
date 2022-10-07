
require 'datadog/tracing/contrib/rails/support/base'
require 'spec/datadog/tracing/contrib/rails/support/deprecation'

RSpec.shared_context 'Rails test application' do
  include_context 'Rails base application'

  before do
    reset_rails_configuration!
    raise_on_rails_deprecation!
  end

  after do
    reset_rails_configuration!
