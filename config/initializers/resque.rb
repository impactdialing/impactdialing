rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
require 'resque_scheduler'
require 'octopus'

unless ENV['REDIS_URL'].nil? || ENV['REDIS_URL'].size.zero?
  url = ENV['REDIS_URL']
else
  redis_config = YAML.load_file(rails_root + '/config/redis.yml')
  url          = redis_config[rails_env]['resque']
end
Resque.redis    = url
Resque.schedule = YAML.load_file("#{Rails.root}/config/resque_schedule.yml")

Dir[File.dirname(__FILE__) + '/../jobs/*.rb'].each do |file|
  require File.basename(file, File.extname(file))
end