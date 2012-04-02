#require File.join("../", 'config/environment')
RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
#ActiveRecord::Base.logger = DIALER_LOGGER #why would you want to log all the sql ??
ActiveRecord::Base.logger = nil #why would you want to log all the sql ??

loop do
  begin
    DIALER_LOGGER.info "starting dialer"
    logged_in_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where on_call=1")
    DIALER_LOGGER.info "============ logged_in_campaigns: #{logged_in_campaigns.num_rows} ============"
    logged_in_campaigns.each do |k|
      campaign = Campaign.find(k.first)
      if campaign.predictive_type != Campaign::Type::PREVIEW && campaign.predictive_type != Campaign::Type::PROGRESSIVE
        campaign.predictive_dial
      end
    end
    sleep 3
  rescue Exception => e
    if e.class==SystemExit
      DIALER_LOGGER.info "============ EXITING  ============"
      exit 
    end
    DIALER_LOGGER.info "DIALER EXCEPTION Rescued - #{ e } (#{ e.class })!"
    DIALER_LOGGER.info "DIALER EXCEPTION Backtrace : #{e.backtrace}"
    ActiveRecord::Base.connection.reconnect!
  end
end