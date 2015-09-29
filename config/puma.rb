workers_count = Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['MAX_THREADS'] || 1)
workers workers_count
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 5000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  # Valid on Rails up to 4.1 the initializer method of setting `pool` size
  ActiveSupport.on_load(:active_record) do
    config = ActiveRecord::Base.configurations[Rails.env] ||
                Rails.application.config.database_configuration[Rails.env]
    config['pool'] = workers_count * threads_count
    ActiveRecord::Base.establish_connection(config)
    ActiveRecord::Base.connection_proxy.instance_variable_get(:@shards).each do |k,v|
      v.clear_reloadable_connections!
    end
  end
  if defined?(Resque)
     Resque.redis = ENV["REDIS_URL"] || "redis://127.0.0.1:6379"
  end
end

