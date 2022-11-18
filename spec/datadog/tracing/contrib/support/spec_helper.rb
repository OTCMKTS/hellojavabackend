require 'spec_helper'

require_relative 'matchers'
require_relative 'resolver_helpers'
require_relative 'tracer_helpers'

RSpec.configure do |config|
  config.include Contrib::TracerHelpers

  # Ra