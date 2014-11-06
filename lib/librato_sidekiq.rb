# https://github.com/mperham/sidekiq/wiki/Middleware
module LibratoSidekiq
  def self.log(msg)
    STDOUT.puts "[LibratoSidekiq] #{msg}"
  end

  class Middleware
    def log(msg)
      LibratoSidekiq.log(msg)
    end

    def initialize(*args)
      log "initializing #{self.class}.new(#{[*args]})"
    end

    def call(worker, msg, queue)
      log "Middleware#call(#{worker}, #{msg}, #{queue})"
      yield
    end

    class Client < Middleware
      def call(worker, msg, queue, redis_pool=nil)
        log "Client#call(#{worker}, #{msg}, #{queue}, #{redis_pool})"
        yield
      end
    end

    class Server < Middleware; end
  end
end