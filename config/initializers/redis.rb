RAILS_ROOT = File.expand_path('../../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
require "eventmachine"
require 'em-http'
require 'em-hiredis'
require 'em-http-request'


rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

redis_config = YAML.load_file(RAILS_ROOT + "/config/redis.yml")

call_flow_uri = URI.parse(redis_config[rails_env]['call_flow'])
$redis_call_flow_connection = Redis.new(:host => call_flow_uri.host, :port => call_flow_uri.port, :password => call_flow_uri.password)

call_end_uri = URI.parse(redis_config[rails_env]['call_end'])
$redis_call_end_connection = Redis.new(:host => call_end_uri.host, :port => call_end_uri.port, :password => call_end_uri.password)


monitor_uri = URI.parse(redis_config[rails_env]['monitor'])
$redis_dialer_connection = Redis.new(:host => monitor_uri.host, :port => monitor_uri.port, :password => monitor_uri.password)

on_hold_uri = URI.parse(redis_config[rails_env]['on_hold_callers'])
$redis_on_hold_connection = Redis.new(:host => on_hold_uri.host, :port => on_hold_uri.port, :password => on_hold_uri.password)


question_pr_uri = URI.parse(redis_config[rails_env]['question_pr'])
$redis_question_pr_uri_connection = Redis.new(:host => question_pr_uri.host, :port => question_pr_uri.port, :password => question_pr_uri.password)


phones_only_uri = URI.parse(redis_config[rails_env]['phones_only_ans'])
$redis_phones_ans_uri_connection = Redis.new(:host => phones_only_uri.host, :port => phones_only_uri.port, :password => phones_only_uri.password)


caller_session_uri = URI.parse(redis_config[rails_env]['caller_session'])
$redis_caller_session_uri_connection = Redis.new(:host => caller_session_uri.host, :port => caller_session_uri.port, :password => caller_session_uri.password)

call_uri = URI.parse(redis_config[rails_env]['call'])
$redis_call_uri_connection = Redis.new(:host => call_uri.host, :port => call_uri.port, :password => call_uri.password)
