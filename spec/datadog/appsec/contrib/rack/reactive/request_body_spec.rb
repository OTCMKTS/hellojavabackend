# frozen_string_literal: true

require 'datadog/appsec/spec_helper'
require 'datadog/appsec/reactive/operation'
require 'datadog/appsec/contrib/rack/gateway/request'
require 'datadog/appsec/contrib/rack/reactive/request_body'
require 'rack'

RSpec.describe Datadog::AppSec::Contrib::Rack::Reactive::RequestBody do
  let(:operation) { Datadog::AppSec::Reactive::Operation.new('test') }
  let(:request) do
    Datadog::AppSec::Contrib::Rack::Gateway::Request.new(
      Rack::MockRequest.env_for(
        'http://example.com:8080/?a=foo',
        { method: 'POST', params: { 'foo' => 'bar' } }
      )
    )
  end

  describe '.publish' do
    it 'propagates request body attributes to the operation' do
      expect(operation).to receive(:publish).with('request.body', { 'foo' => 'bar' })

      described_class.publish(operation, request)
    end
  end

  describe '.subscribe' do
    let(:waf_context) { double(:waf_context) }

    context 'not all addresses have been published' do
      it 'does not call the waf context' do
        expect(operation).to receive(:subscribe).with('request.body').and_call_original
        expect(waf_context).to_not receive(:run)
        described_class.subscribe(operation, waf_context)
      end
    end

    context 'all addresses have been published' do
      it 'does call the waf context with the right arguments' do
        expect(operation).to receive(:subscribe).and_call_original

        expected_waf_arguments = { 'server.request.body' => { 'foo' => 'bar' } }

        waf_result = double(:waf_result, status: :ok, timeout: false)
        expect(waf_context).to receive(:run).with(
          expected_waf_arguments,
          Datadog::AppSec.settings.waf_timeout
        ).and_return(waf_result)
        described_class.subscribe(operation, waf_context)
        result = described_class.publish(operation, request)
        expect(result).to be_nil
      end
    end

    context 'waf result is a match' do
      it 'yields result and no blocking action' do
        expect(operation).to receive(:subscribe).and_call_original

        waf_result = double(:waf_result, status: :match, timeout: false, actions: [''])
        expect(waf_context).to receive(:run).and_return(waf_result)
        described_class.subscribe(operation, waf_context) do |result, block|
          expect(result).to eq(waf_result)
          expect(block).to eq(false)
        end
        result = described_class.publish(operation, request)
        expect(result).to be_nil
 