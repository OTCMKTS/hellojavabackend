# frozen_string_literal: true

require 'datadog/appsec/spec_helper'
require 'datadog/appsec/processor'
require 'datadog/appsec/reactive/operation'
require 'datadog/appsec/contrib/rack/gateway/response'
require 'datadog/appsec/contrib/rack/reactive/response'

RSpec.describe Datadog::AppSec::Contrib::Rack::Reactive::Response do
  let(:operation) { Datadog::AppSec::Reactive::Operation.new('test') }
  let(:waf_context) { instance_double(Datadog::AppSec::Processor::Context) }

  let(:response) do
    Datadog::AppSec::Contrib::Rack::Gateway::Response.new('Ok', 200, {}, active_context: waf_context)
  end

  describe '.publish' do
    it 'propagates response attributes to the operation' do
     