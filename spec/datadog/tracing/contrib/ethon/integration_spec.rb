require 'datadog/tracing/contrib/support/spec_helper'

require 'datadog/tracing/contrib/ethon/integration'

RSpec.describe Datadog::Tracing::Contrib::Ethon::Integration do
  extend ConfigurationHelpers

  let(