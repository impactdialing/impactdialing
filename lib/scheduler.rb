require 'celluloid/autostart' unless Rails.env.test?

##
# Thread-based scheduled queueing of background jobs.

#$CELLULOID_DEBUG = true
#Celluloid.logger = Logger.new $stdout
Celluloid.exception_handler{|exception| Bugsnag.notify(exception) }

class Scheduler
  include Celluloid

  attr_reader :interval, :timer

  autoload :Predictive, 'scheduler/predictive'

  def self.boot!
    Scheduler::Predictive.run!
  end

  def initialize(interval)
    @interval   = interval
  end

  def run
    fail "Not implemented"
  end

  def process
    fail "Not implemented"
  end

  def log(type=:info, msg)
    Logger.send(type, "#{Actor.current.class} #{msg}")
  end
end
