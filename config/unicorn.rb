rails_env = ENV['RAILS_ENV']
rack_env = ENV['RACK_ENV']
worker_processes 2
timeout 30
preload_app true

before_fork do |server, worker|
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection.disconnect!
    Rails.logger.info('Disconnected from ActiveRecord')
  end

  sleep 1
end

after_fork do |server, worker|
  if defined?(ActiveRecord::Base)
    ActiveRecord::Base.connection_proxy.instance_variable_get(:@shards).each do |k,v|
      v.clear_reloadable_connections!
    end
    Rails.logger.info('Connected to ActiveRecord')
  end
end
