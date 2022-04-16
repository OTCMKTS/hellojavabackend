# frozen_string_literal: true

require 'datadog/appsec/spec_helper'
require 'datadog/appsec/reactive/engine'

RSpec.describe Datadog::AppSec::Reactive::Engine do
  subject(:engine) { described_class.new }
  let(:subscribers) { engine.