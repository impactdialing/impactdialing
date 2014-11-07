require 'librato_sidekiq'

# https://github.com/mperham/sidekiq/wiki/Middleware
module LibratoSidekiq
  class Middleware
  private
    def log(level, msg)
      LibratoSidekiq.log(level, msg)
    end

  public
    def initialize(*args)
      LibratoSidekiq.track!
    end
  end
end
