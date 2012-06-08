rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
require 'resque_scheduler'

redis_config = YAML.load_file(rails_root + '/config/redis.yml')
Resque.redis = redis_config[rails_env]
Resque.schedule = YAML.load_file("#{Rails.root}/config/resque_schedule.yml")
require '#{Rails.root}/jobs'
