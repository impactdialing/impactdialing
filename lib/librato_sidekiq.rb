module LibratoSidekiq
  def self.log(msg)
    STDOUT.puts "[LibratoSidekiq] #{msg}"
  end
end

require 'librato_sidekiq/server'