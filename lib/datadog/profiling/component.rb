# frozen_string_literal: true

module Datadog
  module Profiling
    # Profiling component
    module Component
      def build_profiler(settings, agent_settings, tracer)
        return unless settings.profiling.enabled

        # Workaround for weird dependency direction: the Core::Configuration::Components class currently has a
        # dependency on individual products, in this case the Profiler.
        # (Note "currently": in the future we want to change this so core classes don't depend on specific products)
        #
        # If the current file included a `require 'datadog/profiler'` at its beginning, we would generate circular
        # requires when used from profiling:
        #
        # datadog/profiling
        #     └─requires─> datadog/core
        #                      └─requires─> datadog/core/configuration/components
        #                                       └─requires─> datadog/profiling       # Loop!
        #
        # ...thus in #1998 we removed such a require.
        #
        # On the other hand, if datadog/core is loaded by a different product and no general `require 'ddtrace'` is
        # done, then profiling may not be loaded, and thus to avoid this issue we do a require here (which is a
        # no-op if profiling is already loaded).
        require_relative '../profiling'
        return unless Profiling.supported?

        unless defined?(Profiling::Tasks::Setup)
          # In #1545 a user reported a NameError due to this constant being uninitialized
          # I've documented my suspicion on why that happened in
          # https://github.com/DataDog/dd-trace-rb/issues/1545#issuecomment-856049025
          #
          # > Thanks for the info! It seems to feed into my theory: there's two moments in the code where we check if
          # > profiler is "supported": 1) when loading ddtrace (inside preload) and 2) when starting the profile
          # > after Datadog.configure gets run.
          # > The problem is that the code assumes that both checks 1) and 2) will always reach the same conclusion:
          # > either profiler is supported, or profiler is not supported.
          # > In the problematic case, it looks like in your case check 1 decides that profiler is not
          # > supported => doesn't load it, and then check 2 decides that it is => assumes it is loaded and tries to
          # > start it.
          #
          # I was never able to validate if this was the issue or why exactly .supported? would change its mind BUT
          # just in case it happens again, I've left this check which avoids breaking the user's application AND
          # would instead direct them to report it to us instead, so that we can investigate what's wrong.
          #
          # TODO: As of June 2021, most checks in .supported? are related to the google-protobuf gem; so it's
          # very likely that it was the origin of the issue we saw. Thus, if, as planned we end up moving away from
          # protobuf OR enough time has passed and no users saw the issue again, we can remove this check altogether.
          Datadog.logger.error(
            'Profiling was marked as supported and enabled, but setup task was not loaded properly. ' \
            'Please report this at https://github.com/DataDog/dd-trace-rb/blob/master/CONTRIBUTING.md#found-a-bug'
          )

          return
  