require 'active_support/core_ext/string/inflections'

module LibratoSidekiq
  mattr_accessor :tracking do
    false
  end

  def self.log(msg)
    STDOUT.puts "[LibratoSidekiq] #{msg}"
  end

  def self.source(queue, worker, extra=nil)
    worker_name = worker.class.to_s.split('::').last.underscore
    [ENV['LIBRATO_SOURCE'], queue, worker_name, extra].compact.join('.')
  end

  def self.increment(name, queue, worker, extra=nil)
    Librato.group('sidekiq') do |group|
      group.increment(name, source: source(queue, worker, extra))
    end
  end

  def self.track!
    return true if tracking
    log 'tracking started'
    Librato.tracker.start!
    self.tracking = true
  end
end

require 'librato_sidekiq/server'