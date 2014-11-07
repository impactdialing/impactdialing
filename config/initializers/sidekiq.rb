unless ENV['REDIS_URL'].nil? || ENV['REDIS_URL'].size.zero?
  url = ENV['REDIS_URL']
else
  redis_config = YAML.load_file(File.join(Rails.root, "/config/redis.yml"))
  url          = redis_config[Rails.env]['sidekiq']
end

STDOUT.puts "Sidekiq is connecting to #{url}. REDIS_URL is #{ENV['REDIS_URL']}"

Rails.application.config.after_initialize do
  ActiveSupport.on_load(:active_record) do
    require 'librato_sidekiq/server'

    Sidekiq.configure_server do |config|
      config.redis = {
        :url => url,
        :namespace => 'resque'
      }

      require 'impact_platform/mysql'
      min_pool_size = Sidekiq.options[:concurrency]
      ImpactPlatform::MySQL.reconnect!(min_pool_size)

      config.server_middleware do |chain|
        chain.add LibratoSidekiq::ServerTiming
        chain.add LibratoSidekiq::ServerIncrement
      end
    end

    Sidekiq.configure_client do |config|
      config.redis = {
        :url => url,
        :namespace => 'resque'
      }
    end
  end
end