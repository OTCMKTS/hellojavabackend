require 'uri'

# NOTE: This code is copied directly from Redis.
#       Its purpose is to resolve connection information.
#       It exists here only because it doesn't exist in the redis
#       library as a separated module and it allows to avoid
#       instantiating a new Redis::Client for resolving the connection
module Datadog
  module Tracing
    module Contrib
      module Redis
        module Vendor
          class Resolver # :nodoc:
            # Connection DEFAULTS for a Redis::Client are unchanged for
            # the integration supported options.
            # https://github.com/redis/redis-rb/blob/v3.0.0/lib/redis/client.rb#L6-L14
            # https://github.com/redis/redis-rb/blob/v4.1.3/lib/redis/client.rb#L10-L26
            # Since the integration takes in consideration only few attributes, all
            # versions are compatible for :url, :scheme, :host, :port, :db
            DEFAULTS = {
              url: -> { ENV['REDIS_URL'] },
              scheme: 'redis',
              host: '127.0.0.1',
              port: 6379,
              path: nil,
              # :timeout => 5.0,
              password: nil,
              db: 0 # ,
              # :driver => nil,
 