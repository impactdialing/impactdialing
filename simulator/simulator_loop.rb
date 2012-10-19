require 'active_record'
require "ostruct"
require 'yaml'
require 'logger'
require 'fileutils'
require 'octopus'

RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
SIMULATOR_ROOT = ENV['SIMULATOR_ROOT'] || File.expand_path('..', __FILE__)
ActiveRecord::Base.logger = Logger.new(File.open(File.join(SIMULATOR_ROOT, 'log', "simulator_#{ENV['RAILS_ENV']}.log"), 'a'))

loop do
  begin
    Octopus.using(:read_slave2) do
      logged_in_campaigns = CallerSession.campaigns_on_call
      logged_in_campaigns.each do |c|     
        puts "Simulating #{c.campaign_id}"
        campaign = Campaign.find(c.campaign_id)      
        Resque.enqueue(SimulatorJob, campaign.id) if campaign.type == Campaign::Type::PREDICTIVE
      end
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
