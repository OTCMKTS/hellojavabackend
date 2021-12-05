require 'uri'

require_relative '../../metadata/ext'
require_relative '../../propagation/http'
require_relative 'ext'
require_relative '../http_annotation_helper'

module Datadog
  module Tracing
    module Contrib
      module Ethon
     