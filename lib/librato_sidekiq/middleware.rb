# https://github.com/mperham/sidekiq/wiki/Middleware
module LibratoSidekiq
  class Middleware
    def log(msg)
      LibratoSidekiq.log(msg)
    end

    def initialize(*args)
      log "initializing #{self.class}.new(#{[*args]})"
    end

    def call(worker, msg, queue)
      log "Middleware#call(#{worker}, #{msg}, #{queue})"
      begin
        yield

        worker_name = worker.respond_to?(:name) ? worker.name : worker.class.to_s.split('::').last
        source = [queue, worker_name].join('.')
        Librato.group('sidekiq') do |group|
          group.increment 'completed', source: source
        end
        log "Middleware#call - completed"
      rescue => exception
        worker_name = worker.respond_to?(:name) ? worker.name : worker.class.to_s.split('::').last
        source = [queue, worker_name].join('.')
        Librato.group('sidekiq') do |group|
          group.increment 'exception', source: source
        end
        log "Middleware#call - exception: #{exception}"

        raise
      end
    end
  end
end