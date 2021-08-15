require 'spec_helper'
require 'rspec/wait'
require 'securerandom'
require 'json'

RSpec.describe 'Basic scenarios' do
  include_context 'integration test'

  context 'default' do
    subject { get('basic/default') }
    it { is_expected.t