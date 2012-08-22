RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
DIALER_ROOT = ENV['DIALER_ROOT'] || File.expand_path('..', __FILE__)
FileUtils.mkdir_p(File.join(DIALER_ROOT, 'log'), :verbose => true)
ActiveRecord::Base.logger = Logger.new(File.open(File.join(DIALER_ROOT, 'log', "dialer_#{RAILS_ENV}.log"), 'a'))
rails_env = ENV['RAILS_ENV'] || 'development'
redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
uri = URI.parse(redis_config[rails_env])
Resque.redis = Redis.new(:host => uri.host, :port => uri.port)
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"



loop do
  begin
    logged_in_campaigns = CallerSession.campaigns_on_call
    logged_in_campaigns.each do |c|
      campaign = Campaign.find(c.campaign_id)
      if campaign.type != Campaign::Type::PREVIEW && campaign.type != Campaign::Type::PROGRESSIVE && !Resque.redis.exists("dial:#{campaign.id}")
        campaign.dial_resque
      end
    end
    sleep 3
  rescue Exception => e
    if e.class==SystemExit
      puts "============ EXITING  ============"
      exit 
    end
    puts "DIALER EXCEPTION Rescued - #{ e } (#{ e.class })!"
    puts "DIALER EXCEPTION Backtrace : #{e.backtrace}"
  end
end