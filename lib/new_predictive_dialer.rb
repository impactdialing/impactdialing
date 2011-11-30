#require File.join("../", 'config/environment')
require File.join(RAILS_ROOT, 'config/environment')
ActiveRecord::Base.logger = DIALER_LOGGER

loop do
  begin
    logged_in_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where on_call=1")
    DIALER_LOGGER.info "============ logged_in_campaigns: #{logged_in_campaigns.count} ============"
    logged_in_campaigns.each do |k|
      Campaign.find(k.first).predictive_dial
    end
    sleep 3
  rescue Exception => e
    if e.class==SystemExit
      DIALER_LOGGER.info "============ EXITING  ============"
      exit 
    end
    DIALER_LOGGER.info "Rescued - #{ e } (#{ e.class })!"
    DIALER_LOGGER.info e.backtrace
    ActiveRecord::Base.connection.reconnect!
  end
end