RAILS_ROOT = File.expand_path('../../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
require File.join(RAILS_ROOT, 'lib/redis_connection')
require "eventmachine"
require 'em-http'
require 'em-hiredis'
require 'em-http-request'


rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

redis_config = YAML.load_file(RAILS_ROOT + "/config/redis.yml")
call_flow_uri = URI.parse(redis_config[rails_env]['call_flow'])
$redis_call_flow_connection = Redis.new(:host => call_flow_uri.host, :port => call_flow_uri.port)      

monitor_uri = URI.parse(redis_config[rails_env]['monitor_redis'])
$redis_monitor_connection = Redis.new(:host => monitor_uri.host, :port => monitor_uri.port)

dialer_uri = URI.parse(redis_config[rails_env]['dialer'])







