require 'octopus'
RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')


loop do
  begin
    Octopus.using(:simulator_slave) do
      logged_in_campaigns = CallerSession.campaigns_on_call
      logged_in_campaigns.each do |c|     
        puts "Simulating #{c.campaign_id}"
        unless c.campaign_id.nil?
          campaign = Campaign.find(c.campaign_id)      
          Resque.enqueue(SimulatorJob, campaign.id) if campaign.type == Campaign::Type::PREDICTIVE
        end
      end
    end
    
    if ENV['COLLECT_ACTIVE_CALLER_METRICS'].to_i > 0
      a = Time.now.to_f
      CallFlow::Jobs::ActiveCallerMonitor.perform # quick running method to send stats to librato
      b = Time.now.to_f
      d = b - a
      sleep(30 - d.to_i) if d < 30
    else
      sleep(30)
    end

  rescue Exception => e
    if e.class == SystemExit || e.class == Interrupt
      puts "============ EXITING  ============"
      exit
    end
    puts "Rescued - #{ e } (#{ e.class })!"
    puts e.backtrace
  end
end
