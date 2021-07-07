require 'rack'
require 'json'

require_relative 'resque_background_job'
require_relative 'sidekiq_background_job'

module Acme
  class Application
    def call(env)
      request = Rack::Request.new(env)
      router.route!(request)
    end

    def router
      Router.new(
        '/' => { controller: controllers[:health], action: :check },
        '/health' => { controller: controllers[:health], action: :check },
        '/health/detailed' => { controller: controllers[:health], action: :detailed_check },
        '/basic/fibonacci' => { controller: controllers[:basic], action: :fibonacci },
        '/basic/default' => { controller: controllers[:basic], action: :default },
        '/background_jobs/read_resque' => { controller: controllers[:background_jobs], action: :read_resque },
        '/background_jobs/write_resque' => { controller: controllers[:background_jobs], action: :write_resque },
        '/background_jobs/read_sidekiq' => { controller: controllers[:background_jobs], action: :read_sidekiq },
        '/background_jobs/write_sidekiq' => { controller: controllers[:background_jobs], action: :write_sidekiq },
      )
    end

    def controllers
      {
        basic: Controllers::Basic.new