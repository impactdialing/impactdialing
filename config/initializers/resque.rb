rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
require 'resque_scheduler'

redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
uri = URI.parse(redis_config[rails_env]['resque_sidekiq'])
Resque.redis = Redis.new(:host => uri.host, :port => uri.port)
Resque.schedule = YAML.load_file("#{Rails.root}/config/resque_schedule.yml")

Dir[File.dirname(__FILE__) + '/../jobs/*.rb'].each do |file| 
  require File.basename(file, File.extname(file))
end
