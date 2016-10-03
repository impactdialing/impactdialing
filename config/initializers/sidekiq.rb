url = ENV['REDIS_URL']

STDOUT.puts "Sidekiq is connecting to #{url}. REDIS_URL is #{ENV['REDIS_URL']}"

Rails.application.config.after_initialize do
  ActiveSupport.on_load(:active_record) do
    require 'librato_sidekiq/server'

    redis_conn = proc { Redis.new(network_timeout: 3, namespace:"resque", url: url)}

    Sidekiq.configure_server do |config|
      config.redis = ConnectionPool.new(size: 30, &redis_conn)

      require 'impact_platform/mysql'
      min_pool_size = Sidekiq.options[:concurrency]
      ImpactPlatform::MySQL.reconnect!(min_pool_size)

      config.server_middleware do |chain|
        chain.add LibratoSidekiq::ServerTiming
        chain.add LibratoSidekiq::ServerIncrement
      end
    end

    Sidekiq.configure_client do |config|
      config.redis = ConnectionPool.new(size: 5, &redis_conn)
    end
  end
end
