require 'librato_sidekiq/middleware'

module LibratoSidekiq
  class ServerIncrement < Middleware    
    def call(worker, msg, queue)
      log :debug, "ServerStatus#call(#{worker}, #{msg}, #{queue})"
      begin
        yield

        LibratoSidekiq.increment('job_status.completed', queue, worker)
      rescue => exception
        extra = exception.class.to_s.split('::').last.underscore
        LibratoSidekiq.increment('job_status.exception', queue, worker, extra)

        # re-raise
        raise
      end
    end
  end

  class ServerTiming < Middleware
    def call(worker, msg, queue)
      log :debug, "ServerTiming#call(#{worker}, #{msg}, #{queue})"

      LibratoSidekiq.timing(queue, worker) do
        yield
      end
    end
  end
end