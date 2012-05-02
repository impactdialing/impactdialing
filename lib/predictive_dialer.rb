RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
DIALER_ROOT = ENV['DIALER_ROOT'] || File.expand_path('..', __FILE__)
FileUtils.mkdir_p(File.join(DIALER_ROOT, 'log'), :verbose => true)
ActiveRecord::Base.logger = Logger.new(File.open(File.join(DIALER_ROOT, 'log', "dialer_#{RAILS_ENV}.log"), 'a'))


loop do
  begin
    logged_in_campaigns = ActiveRecord::Base.connection.execute("select distinct campaign_id from caller_sessions where on_call=1")
    logged_in_campaigns.each do |k|
      campaign = Campaign.find(k.first)
      if campaign.type != Campaign::Type::PREVIEW && campaign.type != Campaign::Type::PROGRESSIVE
        campaign.dial
      end
    end
  rescue Exception => e
    if e.class==SystemExit
      puts "============ EXITING  ============"
      exit 
    end
    puts "DIALER EXCEPTION Rescued - #{ e } (#{ e.class })!"
    puts "DIALER EXCEPTION Backtrace : #{e.backtrace}"
    ActiveRecord::Base.connection.reconnect!
  end
end