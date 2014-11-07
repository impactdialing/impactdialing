require 'active_support/core_ext/string/inflections'

module LibratoSidekiq
  def self.logger
    return @logger if defined?(@logger)
    if Rails.env =~ /heroku/
      @logger = Logger.new(STDOUT)
    else
      @logger = Logger.new
    end
  end

  def self.log(level, msg)
    logger.send(level, "[LibratoSidekiq] #{msg}")
  end

  def self.worker_name(worker)
    return nil if worker.nil?

    worker.class.to_s.split('::').last.underscore
  end

  def self.source(queue=nil, worker=nil, extra=nil)
    [ENV['LIBRATO_SOURCE'], queue, worker_name(worker), extra].compact.join('.')
  end

  def self.group(&block)
    Librato.group('sidekiq') do |namespace|
      yield namespace
    end
  end

  def self.increment(name, queue, worker, extra=nil)
    group do |namespace|
      namespace.increment(name, source: source(queue, worker, extra))
    end
  end

  def self.timing(queue, worker, &block)
    group do |namespace|
      namespace.timing('worker.time', source: source(queue, worker)) do
        yield
      end
    end
  end

  def self.record_stats
    sidekiq_stats  = ::Sidekiq::Stats.new

    group do |namespace|
      %w(processed failed enqueued retry_size).each do |stat|
        namespace.measure("stats.#{stat}", sidekiq_stats.send(stat), source: source)
      end

      sidekiq_stats.queues.keys.each do |queue_name|
        queue = ::Sidekiq::Queue.new(queue_name)
        namespace.measure('queue.latency', queue.latency, source: source(queue_name))
        namespace.measure('queue.size', queue.size, source: source(queue_name))
      end
    end
  end

  def self.track!
    Librato.tracker.start!
  end
end
