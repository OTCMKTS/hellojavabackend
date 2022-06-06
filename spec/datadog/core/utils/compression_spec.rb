require 'securerandom'
require 'datadog/core/utils/compression'

RSpec.describe Datadog::Core::Utils::Compression do
  describe '::gzip' d