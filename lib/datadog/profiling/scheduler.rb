require_relative '../core/utils/time'

require_relative '../core/worker'
require_relative '../core/workers/polling'

module Datadog
  module Profiling
    # Periodically (every DEFAULT_INTERVAL_SECONDS) takes a profile from the `Exporter` and reports it using the
    # configured transport. Runs on its own background thr