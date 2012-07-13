Sidekiq.configure_server do |config|
  config.redis = { :namespace => 'resque' }
end