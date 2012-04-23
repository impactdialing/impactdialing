class PhonesOnlyCallerSession < CallerSession
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :start_conf, :to => :caller_reassigned, :if => :caller_reassigned_to_another_campaign?
      end 
      
      state :caller_reassigned do
        before(:always) { reassign_caller_session_to_campaign }
        after(:always) { publish_caller_reassignes_to_campaign_for_monitor }
        
        response do |xml_builder, the_call|   
          xml_builder.Say I18n.t(:re_assign_caller_to_another_campaign, :campaign_name => caller.campaign.name)
          xml_builder.Redirect(choose_instructions_option_caller_url(self.caller, :host => Settings.host, :port => Settings.port, :session => id, :Digits => "*"))                 
        end
        
      end
  end
  
    
end