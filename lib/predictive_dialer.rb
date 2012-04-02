#require File.join("../", 'config/environment')
RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
DIALER_ROOT = ENV['DIALER_ROOT'] || File.expand_path('..', __FILE__)
FileUtils.mkdir_p(File.join(DIALER_ROOT, 'log'), :verbose => true)
ActiveRecord::Base.logger = Logger.new(File.open(File.join(DIALER_ROOT, 'log', "dialer_#{RAILS_ENV}.log"), 'a'))


loop do
  begin
    ActiveRecord::Base.logger.info "starting dialer"
    logged_in_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where on_call=1")
    ActiveRecord::Base.logger.info "============ logged_in_campaigns: #{logged_in_campaigns.num_rows} ============"
    logged_in_campaigns.each do |k|
      campaign = Campaign.find(k.first)
      if campaign.predictive_type != Campaign::Type::PREVIEW && campaign.predictive_type != Campaign::Type::PROGRESSIVE
        campaign.predictive_dial
      end
    end
    sleep 3
  rescue Exception => e
    if e.class==SystemExit
      ActiveRecord::Base.logger.info "============ EXITING  ============"
      exit 
    end
    ActiveRecord::Base.logger.info "DIALER EXCEPTION Rescued - #{ e } (#{ e.class })!"
    ActiveRecord::Base.logger.info "DIALER EXCEPTION Backtrace : #{e.backtrace}"
    ActiveRecord::Base.connection.reconnect!
  end
end