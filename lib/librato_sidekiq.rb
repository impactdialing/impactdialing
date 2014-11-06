module LibratoSidekiq
  mattr_accessor :tracking do
    false
  end

  def self.log(msg)
    STDOUT.puts "[LibratoSidekiq] #{msg}"
  end

  def self.track!
    return true if tracking
    log 'tracking started'
    Librato.tracker.start!
    self.tracking = true
  end
end

require 'librato_sidekiq/server'