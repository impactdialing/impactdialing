loop do
  begin
    logged_in_campaigns = CallerSession.campaigns_on_call
    logged_in_campaigns.each do |c|
      puts "Simulating #{c.campaign_id}"
      campaign = Campaign.find(c.campaign_id)
      Resque.enqueue(SimulatorJob, campaign.id) if campaign.type == Campaign::Type::PREDICTIVE
    end
    sleep 30
  rescue Exception => e
    if e.class == SystemExit || e.class == Interrupt
      ActiveRecord::Base.logger.info "============ EXITING  ============"
      exit
    end
    ActiveRecord::Base.logger.info "Rescued - #{ e } (#{ e.class })!"
    ActiveRecord::Base.logger.info e.backtrace
  end
end
