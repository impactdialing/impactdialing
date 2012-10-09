require 'resque-loner'

class AlertJob 
  include Resque::Plugins::UniqueJob  
  @queue = :alert_worker
  
   def self.perform
     Octopus.using(:read_slave1) do
       campaign_ids = CallerSession.campaigns_on_call.pluck(:id)     
       predictive_campaign_ids = Campaign.where("type = 'Predictive' and id in (?)", campaign_ids).pluck(:id)
       alert_on_hold_callers(predictive_campaign_ids)
       alert_not_simulated_campaigns(predictive_campaign_ids)
       alert_dials_not_being_made_for_campaign(predictive_campaign_ids)
    end
   end
   
   def self.alert_dials_not_being_made_for_campaign(predictive_campaign_ids)
     calls_made_in_2_minutes = CallAttempt.where("campaign_id in (?)", predictive_campaign_ids).between(2.minutes.ago, Time.now).group("campaign_id").count
     no_dials = calls_made_in_2_minutes.select {|k,v| v == 0}
     unless no_dials.empty?
       email_all("Dials not made for the following campaigns in the last 2 minutes", no_dials.join(" , ").to_s)
     end     
   end
   
   def self.alert_not_simulated_campaigns(predictive_campaign_ids)
     simulator_not_run_campaigns = []
     simulated_campaigns = SimulatedValues.where("campaign_id in (?)", predictive_campaign_ids).pluck(:campaign_id)
     simulator_not_run_campaigns + predictive_campaign_ids - simulated_campaigns
     simulator_not_run_campaigns + SimulatedValues.where("campaign_id in (?) and updated_at < ?", predictive_campaign_ids, 2.minutes.ago).pluck(:campaign_id)
     unless simulator_not_run_campaigns.blank?
       email_all("Campaigns not Simulated in the last 2 minutes", simulator_not_run_campaigns.join(" , ").to_s)
     end
   end
   
   
   def self.alert_on_hold_callers(predictive_campaign_ids)
     caller_sessions_on_hold_high = CallerSession.available.where("updated_at < ? and campaign_id in (?)", 2.minutes.ago, predictive_campaign_ids).pluck(:id)
     unless caller_sessions_on_hold_high.blank?
       email_all("Callers on hold for long", caller_sessions_on_hold_high.join(" , ").to_s)
     end         
   end
   
   def self.email_all(subject, content)
     user_mailer = UserMailer.new
     user_mailer.alert_email(subject, content)        
   end
end