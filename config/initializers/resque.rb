rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
require 'resque_scheduler'
require 'octopus'

redis_config = YAML.load_file(rails_root + '/config/redis.yml')
Resque.redis = redis_config[rails_env]['resque']
Resque.schedule = YAML.load_file("#{Rails.root}/config/resque_schedule.yml")

Dir[File.dirname(__FILE__) + '/../jobs/*.rb'].each do |file| 
  require File.basename(file, File.extname(file))
end