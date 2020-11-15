# rubocop:disable Style/StderrPuts
# rubocop:disable Style/GlobalVars

if RUBY_ENGINE != 'ruby' || Gem.win_platform?
  $stderr.puts(
    'WARN: Skipping build of ddtrace profiling loader. See ddtrace profiling native extension note for details.'
  )

  File.write('Mak