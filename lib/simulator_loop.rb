Signal.trap("TERM") {
  puts "============ EXITING  ============"
  exit
}

loop do
  begin
    logged_in_campaigns = CallerSession.campaigns_on_call
    logged_in_campaigns.each do |c|
      campaign = Campaign.find(c.campaign_id)
      if campaign.type == Campaign::Type::PREDICTIVE
        Resque.enqueue(SimulatorJob, campaign.id)
      end
    end
    sleep 30
  rescue => e
    ActiveRecord::Base.logger.error "Rescued - #{ e } (#{ e.class })!"
    ActiveRecord::Base.logger.error e.backtrace
  end
end
