RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
DIALER_ROOT = ENV['DIALER_ROOT'] || File.expand_path('..', __FILE__)
FileUtils.mkdir_p(File.join(DIALER_ROOT, 'log'), :verbose => true)
ActiveRecord::Base.logger = Logger.new(File.open(File.join(DIALER_ROOT, 'log', "dialer_#{ENV['RAILS_ENV']}.log"), 'a'))
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

Signal.trap("TERM") {
  puts "============ EXITING  ============"
  exit
}

loop do
  begin
    logged_in_campaigns = RedisPredictiveCampaign.running_campaigns
    logged_in_campaigns.each do |campaign_id|
      campaign = Campaign.find(campaign_id)
      campaign.dial_resque if !campaign.calculate_dialing?
    end
    sleep 3
  rescue => e
    puts "DIALER EXCEPTION Rescued - #{ e } (#{ e.class })!"
    puts "DIALER EXCEPTION Backtrace : #{e.backtrace}"
  end
end