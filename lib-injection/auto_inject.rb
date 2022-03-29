return if ENV['DD_TRACE_SKIP_LIB_INJECTION'] == 'true'

begin
  require 'open3'

  failure_prefix = 'Datadog lib injection failed:'
  support_message = 'For help solving this issue, please contact Datadog support at https://docs.datadoghq.com/help/.'

  _, status = Open3.capture2e({'DD_TRACE_SKIP_LIB_INJECTION' => 'true'}, 'bundle show ddtrace')

  if status.success?
    STDOUT.puts '[ddtrace] ddtrace already installed... skipping auto-injection' if ENV['DD_TRACE_DEBUG'] == 'true'
    return
  end

  require 'bundler'
  require 'shellwords'

  if Bundler.frozen_bundle?
    STDERR.puts "[ddtrace] #{failure_prefix} Cannot inject with frozen Gemfile, run `bundle config unset deployment` to allow lib injection. To learn more about bundler deployment, check https://bundler.io/guides/deploying.html#deploying-your-application. #{support_message}"
    return
  end

  # `version` and `sha` should be replaced by docker build arguments
  version = "<DD_TRACE_VERSION_TO_BE_REPLACED>"
  sha = "<DD_TRACE_SHA_TO_BE_REPLACED>"

  bundle_add_ddtrace_cmd =
    if !version.empty?
      # For public release
      "bundle add ddtrace --require ddtrace/auto_instrument --version #{version.gsub(/^v/, '').shellescape}"
    elsif !sha.empty?
      # For internal testing
      "bundle add ddtrace --require ddtrace/aut