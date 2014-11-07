require 'librato_sidekiq/middleware'

module LibratoSidekiq
  class Client < Middleware
    def call(worker, msg, queue, redis_pool=nil)
      log :debug, "Client#call(#{worker}, #{msg}, #{queue}, #{redis_pool})"
      yield
    end
  end
end
