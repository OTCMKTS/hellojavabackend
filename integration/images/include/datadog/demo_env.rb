module Datadog
  # Helpers to read the application environment
  module DemoEnv
    module_function

    def gem_spec(gem_name, defaults = {})
      args = if local_gem(gem_name)
               [local_gem(gem_name)]
             elsif git_gem(gem_name)
               [git_gem(gem_name)]
             else
               []
             end

      yield(args) if block_given?

      args
    end

    def gem_env_name(gem_name)
      gem_name.upcase.tr('-', '_')
    end

    def local_gem(gem_name)
      local_env_name = "DD_DEMO_ENV_GEM_LOCAL_#{gem_env_name(gem_name)}"

      return unless ENV.key?(local_env_name)

      { path: ENV[local_env_name] }
    end

    def git_gem(gem_name)
      git_env_name = "DD_DEMO_ENV_GEM_GIT_#{gem_env_name(gem_name)}"
      ref_env_name = "DD_DEMO_ENV_GEM_REF_#{gem_env_name(gem_name)}"

      return unless [git_env_name, ref_env_name].all? { |var| ENV.key?(var) && !ENV[var].empty? }

      { git: ENV[git_env_name], ref: ENV[ref_env_name] }
    end

    def process
      ENV['DD_DEMO_ENV_PROCESS']
    end

    def features
      (ENV['DD_DEMO_ENV_FEATURES'] || '').split(',')
    end

    def feature?(feature)
      features.include?(feature)
    end

    def print_env(header = 'Datadog test environment')
      puts "\n==== #{header} ===="
      puts "Ruby version:    #{RUBY_VERSION}"
      puts "Ruby platform:   #{RUBY_PLATFORM}"
      puts "Ruby engine:     #{RUBY_ENGINE}"
      puts "Process:         #{process}"
      puts "Features:        #{features}"
      puts "Rails env:       #{ENV['RAILS_ENV']}" if ENV['RAILS_ENV']
   