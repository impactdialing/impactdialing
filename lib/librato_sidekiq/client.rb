module LibratoSidekiq
  class Client < Middleware
    def call(worker, msg, queue, redis_pool=nil)
      log "Client#call(#{worker}, #{msg}, #{queue}, #{redis_pool})"
      yield
    end
  end
end