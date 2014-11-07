# https://github.com/mperham/sidekiq/wiki/Middleware
module LibratoSidekiq
  class Middleware
  private
    def log(msg)
      LibratoSidekiq.log(msg)
    end

  public
    def initialize(*args)
      LibratoSidekiq.track!
    end
  end
end
