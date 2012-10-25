rails_env = ENV['RAILS_ENV']
if ["aws", "aws_staging"].include?(rails_env)
  pid "/var/www/impactdialing/current/tmp/pids/unicorn.pid"
end
rack_env = ENV['RACK_ENV']
worker_processes (ENV['UNICORN_WORKERS'] ? ENV['UNICORN_WORKERS'].to_i : 3)
timeout (ENV['UNICORN_TIMEOUT'] ? ENV['UNICORN_TIMEOUT'].to_i : 30)
preload_app true
#stderr_path "log/unicorn.stderr.log"

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
