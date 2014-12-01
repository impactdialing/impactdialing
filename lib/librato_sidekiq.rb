require 'active_support/core_ext/string/inflections'

module LibratoSidekiq
  def self.logger
    @logger ||= Rails.logger
  end

  def self.log(level, msg)
    logger.send(level, "[LibratoSidekiq] #{msg}")
  end

  def self.worker_name(worker)
    return nil if worker.nil?

    worker.class.to_s.split('::').last.underscore
  end

  def self.source(queue=nil, worker=nil, extra=nil)
    [ENV['LIBRATO_SOURCE'], 'sidekiq', queue, worker_name(worker), extra].compact.join('.')
  end

  # match prefix defined by heroku librato drain
  def self.metric_prefix
    'heroku.logs'
  end

  def self.sidekiq_queues
    queues = []
    if ENV['SIDEKIQ_QUEUES'].present?
      queues = ENV['SIDEKIQ_QUEUES'].split(',')
    end
    return queues.empty? ? default_sidekiq_queues : queues
  end

  def self.default_sidekiq_queues
    ['call_flow']
  end

  def self.group(&block)
    yield Librato
    # Librato.group('sidekiq') do |namespace|
    #   yield namespace
    # end
  end

  def self.increment(name, queue, worker, extra=nil)
    group do |namespace|
      namespace.increment("#{metric_prefix}.#{name}", source: source(queue, worker, extra))
    end
  end

  def self.timing(queue, worker, &block)
    group do |namespace|
      namespace.timing("#{metric_prefix}.worker.time", source: source(queue, worker)) do
        yield
      end
    end
  end

  def self.record_stats
    sidekiq_stats  = ::Sidekiq::Stats.new

    group do |namespace|
      %w(processed failed enqueued retry_size).each do |stat|
        namespace.measure("#{metric_prefix}.stats.#{stat}", sidekiq_stats.send(stat), source: source)
      end

      sidekiq_queues.each do |queue_name|
        queue   = ::Sidekiq::Queue.new(queue_name)
        namespace.measure("#{metric_prefix}.queue.latency", queue.latency, source: source(queue_name))
        namespace.measure("#{metric_prefix}.queue.size", queue.size, source: source(queue_name))
      end
    end
  end

  def self.track!
    Librato.tracker.start!
  end
end
