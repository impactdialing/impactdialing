require 'resque/errors'
require 'librato_resque'

class CallList::Jobs::Prune
  extend LibratoResque

  @queue = :import

  def self.perform(*args)
  end
end
