class BroadcastCampaignJob
  include HerokuDelayedJobAutoscale::Autoscale
  
  def initialize(campaign_id)
    @campaign = Campaign.find(campaign_id)
  end
  
  def perform            
    begin
      Twilio.default_options[:ssl_ca_file] = File.join(RAILS_ROOT, 'cacert.pem')
      Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
      @campaign.dial
    rescue => e
      puts e.backtrace.join("\n")
      @campaign.stop
    end
    
  end
end