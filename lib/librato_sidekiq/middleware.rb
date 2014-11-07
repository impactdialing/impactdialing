require 'active_support/core_ext/string/inflections'

# https://github.com/mperham/sidekiq/wiki/Middleware
module LibratoSidekiq
  class Middleware
    def log(msg)
      LibratoSidekiq.log(msg)
    end

    def initialize(*args)
      log "initializing #{self.class}.new(#{[*args]})"
      LibratoSidekiq.track!
    end

    def call(worker, msg, queue)
      log "Middleware#call(#{worker}, #{msg}, #{queue})"
      begin
        yield

        worker_name = worker.class.to_s.split('::').last.underscore
        source = [ENV['LIBRATO_SOURCE'], queue, worker_name].join('.')
        Librato.group('sidekiq') do |group|
          group.increment 'completed', source: source
        end
        log "Middleware#call - completed"
      rescue => exception
        worker_name = worker.class.to_s.split('::').last.underscore
        source = [ENV['LIBRATO_SOURCE'], queue, worker_name].join('.')
        Librato.group('sidekiq') do |group|
          group.increment 'exception', source: source
        end
        log "Middleware#call - exception: #{exception}"
        raise
      end
    end
  end
end