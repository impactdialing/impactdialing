class CallEndJob 
  @queue = :background_worker
  
   def self.perform
     predictive_campaign_ids = CallerSession.campaigns_on_call.where("type = 'Predictive'").pluck(:id)     
     simulator_not_run_campaigns = SimulatedValues.where("campaign_id in (?) and updated_at < ?", predictive_campaign_ids, 2.minutes.ago)
     unless simulator_not_run_campaigns.blank?
       simulator_not_run_campaigns.pluck(:campaign_id)
     end
   end
   
   def self.alter_on_hold_callers(predictive_campaign_ids)
     caller_sessions_on_hold_high = CallerSession.available.where("updated_at < ? and campaign_id in (?)", 2.minutes.ago, predictive_campaign_ids)
     unless caller_sessions_on_hold_high.blank?
       caller_session_ids = caller_sessions_on_hold_high.collect{|c| c.id}
       email_all("Callers on hold for long", caller_session_ids.join(" , ").to_s)
     end         
   end
   
   def self.email_all(subject, content)
     user_mailer = UserMailer.new
     user_mailer.alert_email(subject, content)        
   end
end