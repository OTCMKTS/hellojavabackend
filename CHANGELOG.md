
# Changelog

## [Unreleased]

## [1.10.1] - 2023-03-10

### Fixed

* CI: Update TeamCity environment variable support ([#2668][])
* Core: Fix spurious dependency on AppSec when loading CI with `require 'datadog/ci'` ([#2679][])
* Core: Allow multiple headers and multiple IPs per header for client IP ([#2665][])
* AppSec: prevent side-effect on AppSec login event tracking method arguments ([#2663][]) ([@coneill-enhance][])

## [1.10.0] - 2023-03-06

### Added

* Support Ruby 3.2 ([#2601][])
* Publish init container image (beta) for `dd-trace-rb` injection through K8s admission controller ([#2606][])
* Tracing: Support 128 bits trace id  ([#2543][])
* Tracing: Add tags to integrations (`que` / `racecar` / `resque`/ `shoryken` / `sneakers` / `qless` / `delayed_job` / `kafka` / `sidekiq` / `dalli` / `presto` / `elasticsearch`) ([#2619][],  [#2613][] , [#2608][], [#2590][])
* Appsec: Introduce `AppSec::Instrumentation::Gateway::Argument` ([#2648][])
* Appsec: Block request when user ID matches rules  ([#2642][])
* Appsec: Block request base on response addresses matches ([#2605][])
* Appsec: Allow to set user id denylist ([#2612][])
* Profiling: Show profiler overhead in flamegraph for CPU Profiling 2.0 ([#2607][])
* Profiling: Add support for allocation samples to `ThreadContext` ([#2657][])
* Profiling: Exclude disabled profiling sample value types from output ([#2634][])
* Profiling: Extend stack collector to record the alloc-samples metric ([#2618][])
* Profiling: Add `Profiling.allocation_count` API for new profiler ([#2635][])

### Changed

* Tracing: `rack` instrumentation counts time spent in queue as part of the `http_server.queue` span ([#2591][]) ([@agrobbin][])
* Appsec: Update ruleset to 1.5.2 ([#2662][], [#2659][], [#2598][])
* Appsec: Update `libddwaf` version to 1.6.2.0.0 ([#2614][])
* Profiling: Upgrade profiler to use `libdatadog` v2.0.0 ([#2599][])
* Profiling: Remove support for profiling Ruby 2.2 ([#2592][])

### Fixed

* Fix broken Ruby VM statistics for Ruby 3.2 ([#2600][])
* Tracing: Fix 'uninitialized constant GRPC::Interceptor' error with 'gapic-common' gem ([#2649][])
* Profiling: Fix profiler not adding the "In native code" placeholder ([#2594][])
* Fix profiler detection for google-protobuf installation ([#2595][])

## [1.9.0] - 2023-01-30

As of ddtrace 1.9.0, CPU Profiling 2.0 is now in opt-in (that is, disabled by default) public beta. For more details, check the release notes.

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.9.0

### Added

* Tracing: Add `Stripe` instrumentation ([#2557][])
* Tracing: Add configurable response codes considered as errors for `Net/HTTP`, `httprb` and `httpclient` ([#2501][], [#2576][])([@caramcc][])
* Tracing: Flexible header matching for HTTP propagator ([#2504][])
* Tracing: `OpenTelemetry` Traces support ([#2496][])
* Tracing: W3C: Propagate unknown values as-is ([#2485][])
* Appsec: Add event kit API ([#2512][])
* Profiling: Allow profiler development on arm64 macOS ([#2573][])
* Core: Add `profiling_enabled` state to environment logger output ([#2541][])
* Core: Add 'type' to `OptionDefinition` ([#2493][])
* Allow `debase-ruby_core_source` 3.2.0 to be used ([#2526][])

### Changed

* Profiling: Upgrade to `libdatadog` to `1.0.1.1.0` ([#2530][])
* Appsec: Update appsec rules `1.4.3` ([#2580][])
* Ci: Update CI Visibility metadata extraction ([#2586][])

### Fixed

* Profiling: Fix wrong `libdatadog` version being picked during profiler build ([#2531][])
* Tracing: Support `PG` calls with a block ([#2522][])
* Ci: Fix error in `teamcity` env vars ([#2562][])

## [1.8.0] - 2022-12-14

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.8.0

As of ddtrace 1.8.0, CPU Profiling 2.0 is now in opt-in (that is, disabled by default) public beta. For more details,
check the release notes.

### Added

* Core: Profiling: [PROF-6559] Mark Ruby CPU Profiling 2.0 as being in beta ([#2489][])
* Tracing: Attempt to parse future version of TraceContext ([#2473][])
* Tracing: Add DD_TRACE_PROPAGATION_STYLE option ([#2466][])
* Integrations: Tracing: SQL comment propagation full mode with traceparent ([#2464][])
* Integrations: Tracing: Wire W3C propagator to HTTP & gRPC propagation ([#2458][])
* Integrations: Tracing: Auto-instrumentation with service_name from environmental variable ([#2455][])
* Core: Integrations: Tracing: Deprecation notice for B3 propagation configuration ([#2454][])
* Tracing: Add W3C Trace Context propagator ([#2451][])
* Integrations: Tracing: Redis 5 Instrumentation ([#2428][])

### Changed

* Tracing: Changes `error.msg` to `error.message` for UNC ([#2469][])
* Tracing: Semicolons not allowed in 'origin' ([#2461][])
* Core: Dev/refactor: Tracing: Dev/internal: Move Utils#next_id and constants to Tracing::Utils ([#2463][])
* Core: Dev/refactor: Tracing: Dev/internal: Move Tracing config settings from Core to Tracing ([#2459][])
* Core: Dev/refactor: Tracing: Dev/internal: Move Tracing diagnostic code from Core to Tracing ([#2453][])

### Fixed

* Integrations: Tracing: Improve redis integration patching ([#2470][])
* Tracing: Extra testing from W3C spec ([#2460][])

## [1.7.0] - 2022-11-29

### Added
* Integrations: Support que 2 ([#2382][]) ([@danhodge][])
* Tracing: Unified tagging `span.kind` as `server` and `client` ([#2365][])
* Tracing: Adds `span.kind` tag for `kafka`, `sidekiq`, `racecar`,  `que`, `shoryuken`, `sneakers`, and `resque` ([#2420][], [#2419][], [#2413][], [#2394][])
* Tracing: Adds `span.kind` with values `producer` and `consumer` for `delayed_job` ([#2393][])
* Tracing: Adds `span.kind` as `client` for `redis` ([#2392][])
* Appsec: Pass HTTP client IP to WAF ([#2316][])
* Unified tagging `process_id` ([#2276][])

### Changed
* Allow `debase-ruby_core_source` 0.10.18 to be used ([#2435][])
* Update AppSec ruleset to v1.4.2 ([#2390][])
* Refactored clearing of profile data after Ruby app forks ([#2362][], [#2367][])
* Tracing: Move distributed propagation to Contrib ([#2352][])

### Fixed
* Fix ddtrace installation issue when users have CI=true ([#2378][])

## [1.6.1] - 2022-11-16

### Changed

* Limit `redis` version support to less than 5

### Fixed

* [redis]: Fix frozen input for `Redis.new(...)`

## [1.6.0] - 2022-11-15

### Added

* Trace level tags propagation in distributed tracing  ([#2260][])
* [hanami]: Hanami 1.x instrumentation ([#2230][])
* [pg, mysql2]: option `comment_propagation` for SQL comment propagation, default is `disabled` ([#2339][])([#2324][])

### Changed

* [rack, sinatra]: Squash nested spans and improve patching mechanism.<br> No need to `register Datadog::Tracing::Contrib::Sinatra::Tracer`([#2217][])
* [rails, rack]: Fix Non-GET request method with rails exception controller ([#2317][])
* Upgrade to libdatadog 0.9.0.1.0 ([#2302][])
* Remove legacy profiling transport ([#2062][])

### Fixed

* [redis]: Fix redis instance configuration, not on `client` ([#2363][])
```
# Change your code from
Datadog.configure_onto(redis.client, service_name: '...')
# to
Datadog.configure_onto(redis, service_name: '...')
```
* Allow `DD_TAGS` values to have the colon character ([#2292][])
* Ensure that `TraceSegment` can be reported correctly when they are dropped ([#2335][])
* Docs: Fixes upgrade guide on configure_onto ([#2307][])
* Fix environment logger with IO transport ([#2313][])

## [1.5.2] - 2022-10-27

### Deprecation notice

- `DD_TRACE_CLIENT_IP_HEADER_DISABLED` was changed to `DD_TRACE_CLIENT_IP_ENABLED`. Although the former still works we encourage usage of the latter instead.

### Changed

- `http.client_ip` tag collection is made opt-in for APM. Note that `http.client_ip` is always collected when ASM is enabled as part of the security service provided ([#2321][], [#2331][])

### Fixed

- Handle REQUEST_URI with base url ([#2328][], [#2330][])

## [1.5.1] - 2022-10-19

### Changed

* Update libddwaf to 1.5.1 ([#2306][])
* Improve libddwaf extension memory management ([#2306][])

### Fixed

* Fix `URI::InvalidURIError` ([#2310][], [#2318][]) ([@yujideveloper][])
* Handle URLs with invalid characters ([#2311][], [#2319][])
* Fix missing appsec.event tag ([#2306][])
* Fix missing Rack and Rails request body parsing for AppSec analysis ([#2306][])
* Fix unneeded AppSec call in a Rack context when AppSec is disabled ([#2306][])
* Fix spurious AppSec instrumentation ([#2306][])

## [1.5.0] - 2022-09-29

### Deprecation notice

* `c.tracing.instrument :rack, { quantize: { base: ... } }` will change its default from `:exclude` to `:show` in a future version. Voluntarily moving to `:show` is recommended.
* `c.tracing.instrument :rack, { quantize: { query: { show: ... } }` will change its default to `:all` in a future version, together with `quantize.query.obfuscate` changing to `:internal`. Voluntarily moving to these future values is recommended.

### Added

* Feature: Single Span Sampling ([#2128][])
* Add query string automatic redaction ([#2283][])
* Use full URL in `http.url` tag ([#2265][])
* Add `http.useragent` tag ([#2252][])
* Add `http.client_ip` tag for Rack-based frameworks ([#2248][])
* Ci-app: CI: Fetch committer and author in Bitrise ([#2258][])

### Changed

* Bump allowed version of debase-ruby_core_source to include v0.10.17 ([#2267][])

### Fixed

* Bug: Fix `service_nam` typo to `service_name` ([#2296][])
* Bug: Check AppSec Rails for railties instead of rails meta gem ([#2293][]) ([@seuros][])
* Ci-app: Correctly extract commit message from AppVeyor ([#2257][])

## [1.4.2] - 2022-09-27

### Fixed

OpenTracing context propagation ([#2191][], [#2289][])

## [1.4.1] - 2022-09-15

### Fixed

* Missing distributed traces when trace is dropped by priority sampling ([#2101][], [#2279][])
* Profiling support when Ruby is compiled without a shared library ([#2250][])

## [1.4.0] - 2022-08-25

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.4.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v1.3.0...v1.4.0

### Added

* gRPC: tag `grpc.client.deadline` ([#2200][])
* Implement telemetry, disable by default ([#2153][])

### Changed

* Bump `libdatadog` dependency version ([#2229][])

### Fixed

* Fix CI instrumentation configuration ([#2219][])

## [1.3.0] - 2022-08-04

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.3.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v1.2.0...v1.3.0

### Added

* Top-level span being tagged to avoid duplicate computation ([#2138][])

### Changed

* ActiveSupport: Optionally disable tracing with Rails ([@marcotc][])
* Rack: Resource overwritten by nested application ([#2180][])
* Rake: Explicit task instrumentation to prevent memory bloat ([#2174][])
* Sidekiq and DelayedJob: Add spans to improve tracing ([#2170][])
* Drop Profiling support for Ruby 2.1 ([#2140][])
* Migrate `libddprof` dependency to `libdatadog` ([#2061][])

### Fixed

* Fix OpenTracing propagation with TraceDigest ([#2201][])
* Fix SpanFilter dropping descendant spans ([#2074][])
* Redis: Fix Empty pipelined span being dropped ([#757][]) ([@sponomarev][])
* Fix profiler not restarting on `Process.daemon` ([#2150][])
* Fix setting service from Rails configuration ([#2118][]) ([@agrobbin][])
* Some document and development improvement ([@marocchino][]) ([@yukimurasawa][])

## [1.2.0] - 2022-07-11

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.2.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v1.1.0...v1.2.0

Special thanks go to [@miketheman][] for gifting Datadog access to the `datadog` gem a few days ago.

### Added

* Add Postgres (`pg` gem) instrumentation ([#2054][]) ([@jennchenn][])
* Add env var for debugging profiling native extension compilation issues ([#2069][])
* Teach Rest Client integration the `:split_by_domain` option ([#2079][]) ([@agrobbin][])
* Allow passing request_queuing option to Rack through Rails tracer ([#2082][]) ([@KieranP][])
* Add Utility to Collect Platform Information ([#2097][]) ([@jennchenn][])
* Add convenient interface for getting and setting tags using `[]` and `[]=` respectively ([#2076][]) ([@ioquatix][])
* Add b3 metadata in grpc ([#2110][]) ([@henrich-m][])

### Changed

* Profiler now reports profiling data using the libddprof gem ([#2059][])
* Rename `Kernel#at_fork_blocks` monkey patch to `Kernel#ddtrace_at_fork_blocks` ([#2070][])
* Improved error message for enabling profiling when `pkg-config` system tool is not installed ([#2134][])

### Fixed

* Prevent errors in `action_controller` integration when tracing is disabled ([#2027][]) ([@ahorner][])
* Fix profiler not building on ruby-head (3.2) due to VM refactoring ([#2066][])
* Span and trace IDs should not be zero ([#2113][]) ([@albertvaka][])
* Fix object_id usage as thread local key ([#2096][])
* Fix profiling not working on Heroku and AWS Elastic Beanstalk due to linking issues ([#2125][])

## [1.1.0] - 2022-05-25

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.1.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v1.0.0...v1.1.0

### Added

* [Application Security Monitoring](https://docs.datadoghq.com/security_platform/application_security/)
* Elasticsearch: v8.0 support ([#1985][])
* Sidekiq: Quantize args ([#1972][]) ([@dudo][])
* Profiling: Add libddprof dependency to power the new Ruby profiler ([#2028][])
* Helper to easily enable core dumps ([#2010][])

### Changed

* Support spaces in environment variable DD_TAGS ([#2011][])

### Fixed

* Fix "circular require considered harmful" warnings ([#1998][])
* Logging: Change ddsource to a scalar value ([#2022][])
* Improve exception logging ([#1992][])

## [1.0.0] - 2022-04-28

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.0.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v1.0.0.beta2...v1.0.0

Diff since last stable release: https://github.com/DataDog/dd-trace-rb/compare/v0.54.2...v1.0.0

### Added

- GraphQL 2.0 support ([#1982][])

### Changed

- AppSec: Update libddwaf to 1.3.0 ([#1981][])

### Fixed

- Rails log correlation ([#1989][]) ([@cwoodcox][])
- Resource not inherited from lazily annotated spans ([#1983][])
- AppSec: Query address for libddwaf ([#1990][])

### Refactored

- Docs: Add undocumented Rake option ([#1980][]) ([@ecdemis123][])
- Improvements to test suite & CI ([#1970][], [#1974][], [#1991][])
- Improvements to documentation ([#1984][])

## [1.0.0.beta2] - 2022-04-14

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.0.0.beta2

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v1.0.0.beta1...v1.0.0.beta2

### Added

- Ruby 3.1 & 3.2 support ([#1975][], [#1955][])
- Trace tag API ([#1959][])

### Changed

- Access to configuration settings is namespaced ([#1922][])
- AWS provides metrics by default ([#1976][]) ([@dudo][])
- Update `debase-ruby_core_source` version ([#1964][])
- Profiling: Hide symbols/functions in native extension ([#1968][])
- Profiling: Renamed code_provenance.json to code-provenance.json ([#1919][])
- AppSec: Update libddwaf to v1.2.1 ([#1942][])
- AppSec: Update rulesets to v1.3.1 ([#1965][], [#1961][], [#1937][])
- AppSec: Avoid exception on missing ruleset file ([#1948][])
- AppSec: Env var consistency ([#1938][])

### Fixed

- Rake instrumenting while disabled ([#1940][], [#1945][])
- Grape instrumenting while disabled ([#1940][], [#1943][])
- CI: require 'datadog/ci' not loading dependencies ([#1911][])
- CI: RSpec shared example file names ([#1816][]) ([@Drowze][])
- General documentation improvements ([#1958][], [#1933][], [#1927][])
- Documentation fixes & improvements to 1.0 upgrade guide ([#1956][], [#1973][], [#1939][], [#1914][])

### Removed

- OpenTelemetry extensions (Use [OTLP](https://docs.datadoghq.com/tracing/setup_overview/open_standards/#otlp-ingest-in-datadog-agent) instead) ([#1917][])

### Refactored

- Agent settings resolver logic ([#1930][], [#1931][], [#1932][])

## [1.0.0.beta1] - 2022-02-15

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v1.0.0.beta1

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.54.2...v1.0.0.beta1

See https://github.com/DataDog/dd-trace-rb/blob/v1.0.0.beta1/docs/UpgradeGuide.md.

## [0.54.2] - 2022-01-18

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v0.54.2

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.54.1...v0.54.2

### Changed

- Bump `debase-ruby_core_source` dependency version; also allow older versions to be used ([#1798][], [#1829][])
- Profiler: Reduce impact of reporting data in multi-process applications ([#1807][])
- Profiler: Update API used to report data to backend ([#1820][])

### Fixed

- Gracefully handle installation on environments where Ruby JIT seems to be available but is actually broken ([#1801][])

## [0.54.1] - 2021-11-30

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v0.54.1

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.54.0...v0.54.1

### Fixed

- Skip building profiling native extension when Ruby has been compiled without JIT ([#1774][], [#1776][])

## [0.54.0] - 2021-11-17

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v0.54.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.53.0...v0.54.0

### Added

- MongoDB service name resolver when using multi cluster ([#1423][]) ([@skcc321][])
- Service name override for ActiveJob in Rails configuration ([#1703][], [#1770][]) ([@hatstand][])
- Profiler: Expose profile duration and start to the UI ([#1709][])
- Profiler: Gather CPU time without monkey patching Thread ([#1735][], [#1740][])
- Profiler: Link profiler samples to individual web requests ([#1688][])
- Profiler: Capture threads with empty backtrace ([#1719][])
- CI-App: Memoize environment tags to improve performance ([#1762][])
- CI-App: `test.framework_version` tag for rspec and cucumber ([#1713][])

### Changed

- Set minimum version of dogstatsd-ruby 5 series to 5.3 ([#1717][])
- Use USER_KEEP/USER_REJECT for RuleSampler decisions ([#1769][])

### Fixed

- "private method `ruby2_keywords' called" errors ([#1712][], [#1714][])
- Configuration warning when Agent port is a String ([#1720][])
- Ensure internal trace buffer respects its maximum size ([#1715][])
- Remove erroneous maximum resque version support ([#1761][])
- CI-App: Environment variables parsing precedence ([#1745][], [#1763][])
- CI-App: GitHub Metadata Extraction ([#1771][])
- Profiler: Missing thread id for natively created threads ([#1718][])
- Docs: Active Job integration example code ([#1721][]) ([@y-yagi][])

### Refactored

- Redis client patch to use prepend ([#1743][]) ([@justinhoward][])

## [0.53.0] - 2021-10-06

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v0.53.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.52.0...v0.53.0

### Added

- ActiveJob integration ([#1639][]) ([@bensheldon][])
- Instrument Action Cable subscribe/unsubscribe hooks ([#1674][]) ([@agrobbin][])
- Instrument Sidekiq server internal events (heartbeat, job fetch, and scheduled push) ([#1685][]) ([@agrobbin][])
- Correlate Active Job logs to the active DataDog trace ([#1694][]) ([@agrobbin][])
- Runtime Metrics: Global VM cache statistics ([#1680][])
- Automatically send traces to agent Unix socket if present ([#1700][])
- CI-App: User Provided Git Metadata ([#1662][])
- ActionMailer integration ([#1280][])

### Changed

- Profiler: Set Sinatra resource setting at beginning of request and delay setting fallback resource ([#1628][])
- Profiler: Use most recent event for trace resource name ([#1695][])
- Profiler: Limit number of threads per sample ([#1699][])
- Profiler: Rename `extract_trace_resource` to `endpoint.collection.enabled` ([#1702][])

### Fixed

- Capture Rails exception before default error page is rendered ([#1684][])
- `NoMethodError` in sinatra integration when Tracer middleware is missing ([#1643][], [#1644][]) ([@mscrivo][])
- CI-App: Require `rspec-core` for RSpec integration ([#1654][]) ([@elliterate][])
- CI-App: Use the merge request branch on merge requests ([#1687][]) ([@carlallen][])
- Remove circular dependencies. ([#1668][]) ([@saturnflyer][])
- Links in the Table of Contents ([#1661][]) ([@chychkan][])
- CI-App: Fix CI Visibility Spec Tests ([#1706][])

### Refactored

- Profiler: pprof encoding benchmark and improvements ([#1511][])

## [0.52.0] - 2021-08-09

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v0.52.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.51.1...v0.52.0

### Added

- Add Sorbet typechecker to dd-trace-rb ([#1607][])

  Note that no inline type signatures were added, to avoid a hard dependency on sorbet.

- Profiler: Add support for annotating profiler stacks with the resource of the active web trace, if any ([#1623][])

  Note that this data is not yet visible on the profiling interface.

- Add error_handler option to GRPC tracer configuration ([#1583][]) ([@fteem][])
- User-friendly handling of slow submissions on shutdown ([#1601][])
- Profiler: Add experimental toggle to disable the profiling native extension ([#1594][])
- Profiler: Bootstrap profiling native extension ([#1584][])

### Changed

- Profiler: Profiling data is no longer reported when there's less than 1 second of data to report ([#1630][])
- Move Grape span resource setting to beginning of request ([#1629][])
- Set resource in Sinatra spans at the beginning of requests, and delay setting fallback resource to end of requests ([#1628][])
- Move Rails span resource setting to beginning of request ([#1626][])
- Make registry a global constant repository ([#1572][])
- Profiler: Remove automatic agentless support ([#1590][])

### Fixed

- Profiler: Fix CPU-time accounting in Profiling when fibers are used ([#1636][])
- Don't set peer.service tag on grpc.server spans ([#1632][])
- CI-App: Fix GitHub actions environment variable extraction ([#1622][])
- Additional Faraday 1.4+ cgroup parsing formats ([#1595][])
- Avoid shipping development cruft files in gem releases ([#1585][])

## [0.51.1] - 2021-07-13

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v0.51.1

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.51.0...v0.51.1

### Fixed

- AWS-SDK instrumentation without `aws-sdk-s3` ([#1592][])

## [0.51.0] - 2021-07-12

Release notes: https://github.com/DataDog/dd-trace-rb/releases/tag/v0.51.0

Git diff: https://github.com/DataDog/dd-trace-rb/compare/v0.50.0...v0.51.0

### Added

- Semantic Logger trace correlation injection ([#1566][])
- New and improved Lograge trace correlation injection ([#1555][])
- Profiler: Start profiler on `ddtrace/auto_instrument`
- CI-App: Add runtime and OS information ([#1587][])
- CI-App: Read metadata from local git repository ([#1561][])

### Changed