rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'

redis_config = YAML.load_file(rails_root + '/config/redis.yml')
# Redis = redis_config[rails_env]

redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
uri = URI.parse(redis_config[rails_env]['monitor_redis'])

$redis_monitor_connection = Redis.new(:host => uri.host, :port => uri.port)      

