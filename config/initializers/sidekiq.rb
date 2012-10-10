rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
if rails_env == 'development' || rails_env == "test"  
else  
  Sidekiq.configure_server do |config|
    config.redis = { :url => redis_config[rails_env]['resque_sidekiq'], :namespace => 'resque', :size => (Sidekiq.options[:concurrency] + 2) }    
  end

  Sidekiq.configure_client do |config|
    config.redis = { :url => redis_config[rails_env]['resque_sidekiq'], :namespace => 'resque', :size => (Sidekiq.options[:concurrency] + 2)}
  end    
end