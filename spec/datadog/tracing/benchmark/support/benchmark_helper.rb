require 'spec_helper'

require 'datadog/statsd'
require 'ddtrace'

require 'benchmark/ips'
unless PlatformHelpers.jruby?
  require 'benchmark/memory'
  require 'memory_profiler'
end

require 'fileutils'
require 'json'

RSpec.shared_context 'benchmark' do
  # When applicable, runs the test subject for different input sizes.
  # Similar to how N in Big O notation works.
  #
  # This value is provided to the `subject(i)` method in order for the test
  # to appropriately execute its run based on input size.
  let(:steps) { defined?(super) ? super() : [1, 10, 100] }

  # How many times we run our program when testing for memory allocation.
  # In theory, we should only need to run it once, as memory tests are not
  # dependent on competing system resources.
  # But occasionally we do see a few blimps of inconsistency, making the benchmarks skewed.
  # By running the benchmarked snippet many times, we drown out any one-off anomalies, allowing
  # the real memory culprits to surface.
  let(:memory_iterations) { defined?(super) ? super() : 100 }

  # How long the program will run when calculating IPS performance, in seconds.
  let(:timing_runtime) {