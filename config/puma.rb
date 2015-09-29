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
  # Valid on Rails up to 4.1 the initializer method of setting `pool` size
  ActiveSupport.on_load(:active_record) do
    ImpactPlatform::MySQL.reconnect!(workers_count * threads_count)
    redis_url = ENV['REDIS_URL']
    Resque.redis = redis_url
    Sidekiq.configure_client do |config|
      config.redis = {
        :url => redis_url,
        :namespace => 'resque'
      }
    end
  end
end

on_restart do
  $redis_call_flow_connection.disconnect
  $redis_call_end_connection.disconnect
  $redis_dialer_connection.disconnect
  $redis_on_hold_connection.disconnect
  $redis_question_pr_uri_connection.disconnect
  $redis_phones_ans_uri_connection.disconnect
  $redis_caller_session_uri_connection.disconnect
  $redis_call_uri_connection.disconnect
  Resque.redis.disconnect
  Sidekiq.redis.disconnect
  ImpactPlatform::MySQL.disconnect!
end
