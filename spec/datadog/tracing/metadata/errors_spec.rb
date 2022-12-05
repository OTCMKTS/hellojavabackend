require 'spec_helper'

require 'datadog/tracing/metadata/tagging'
require 'datadog/tracing/metadata/errors'

RSpec.describe Datadog::Tracing::Metadata::Errors do
  subject(:test_object) { test_class.new }
  let(:test_class) do
    Class.new do
      include Datadog::Tracing::Metadata::Tagging
      include Datadog::Tracing::Metadata::Errors
    end
  end

  describe '#set_error' do
    subject(:set_error) { test_object.set_error(error) }

    let(:error) { RuntimeError.new('oops') }
    let(:backtrace) { %w[method1 method2 meth