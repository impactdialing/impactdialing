require File.join(File.dirname(File.absolute_path(__FILE__)), '..', 'lib', 'impact_platform', 'mysql')

workers_count = Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 1)
workers workers_count
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 5000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  # Valid on Rails up to 4.1 
  redis_url    = ENV['REDIS_URL']
  Resque.redis = redis_url
  redis_conn = proc {
     Redis.new(:url=>redis_url, :namespace=>'resque', :timeout=>2) # do anything you want here
  }
  Sidekiq.configure_client do |config|
    config.redis = ConnectionPool.new(size: 5, &redis_conn)
  end

    # config.redis = {
    #   :url => redis_url,
    #   :namespace => 'resque'
    # }


  ActiveSupport.on_load(:active_record) do
    ImpactPlatform::MySQL.reconnect!(workers_count * threads_count)
  end
end

on_restart do
  ImpactPlatform::MySQL.disconnect!
end
