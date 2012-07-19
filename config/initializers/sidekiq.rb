Sidekiq.configure_server do |config|
  config.redis = { :size => (Sidekiq.options[:concurrency] + 2) }
end