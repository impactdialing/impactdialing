rails_root = ENV['RAILS_ROOT'] || File.dirname(__FILE__) + '/../..'
rails_env = ENV['RAILS_ENV'] || 'development'
require 'resque_scheduler'
require 'octopus'

url             = ENV['REDIS_URL']
Resque.redis    = url
Resque.schedule = YAML.load_file("#{Rails.root}/config/resque_schedule.yml")

Dir[File.dirname(__FILE__) + '/../jobs/*.rb'].each do |file|
  require File.basename(file, File.extname(file))
end
