class WebuiCallerSession < CallerSession
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :start_conf, :to => :caller_reassigned, :if => :caller_reassigned_to_another_campaign?
      end 
      
      state :caller_reassigned do
        before(:always) { reassign_caller_session_to_campaign}
        after(:always) {publish_caller_reassigned_to_campaign}
        
      end
  end
  
end