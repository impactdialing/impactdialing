# https://github.com/mperham/sidekiq/wiki/Middleware
module LibratoSidekiq
  class Middleware
  private
    def log(msg)
      LibratoSidekiq.log(msg)
    end

  public
    def initialize(*args)
      LibratoSidekiq.track!
    end

    def call(worker, msg, queue)
      log "Middleware#call(#{worker}, #{msg}, #{queue})"
      begin
        yield

        LibratoSidekiq.increment('completed', queue, worker)
      rescue => exception
        extra = exception.class.to_s.split('::').last.underscore
        LibratoSidekiq.increment('exception', queue, worker, extra)

        # re-raise
        raise
      end
    end
  end
end
