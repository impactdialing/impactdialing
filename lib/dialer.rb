require File.join(RAILS_ROOT, 'config/environment')

logger = Logger.new(Rails.root.join("log", "dialer_#{RAILS_ENV}.log"))
ActiveRecord::Base.logger = logger
campaign_id = ARGV.first.to_i
campaign = Campaign.find(campaign_id)

begin
  logger.info "[dialer] Started daemon for dialing campaign id:#{campaign.id} name:#{campaign.name}"
  Twilio.default_options[:ssl_ca_file] = File.join(RAILS_ROOT, 'cacert.pem')
  Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
  campaign.dial
rescue => e
  logger.error "[dialer] Stopping daemon for campaign : #{campaign.name}, because : #{e.message} :::::::: #{e.backtrace}"
  campaign.stop
end

