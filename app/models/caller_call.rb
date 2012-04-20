class CallerCall < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallCenter
  include Event
  
  has_one :caller_session
  
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :incoming_call, :to => :connected
      end 
      
      state :connected do
        
      end
      
      
  end
end  