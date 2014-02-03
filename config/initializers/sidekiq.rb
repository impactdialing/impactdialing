redis_config = YAML.load_file(File.join(Rails.root, "/config/redis.yml"))

Rails.application.config.after_initialize do
  ActiveSupport.on_load(:active_record) do
    Sidekiq.configure_server do |config|
      config.redis = {
        :url => redis_config[Rails.env]['sidekiq'],
        :namespace => 'resque'
      }

      require 'platform'
      min_pool_size = Sidekiq.options[:concurrency]
      Platform::MySQL.reconnect!(min_pool_size)
    end

    Sidekiq.configure_client do |config|
      config.redis = {
        :url => redis_config[Rails.env]['sidekiq'],
        :namespace => 'resque'
      }
    end
  end
end