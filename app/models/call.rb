class Call < ActiveRecord::Base
  has_one :call_attempt
  serialize :conference_history, Array
  delegate :connect_call, :to => :call_attempt
  delegate :abandon_call, :to => :call_attempt
  delegate :ended, :to => :call_attempt
  delegate :caller_not_available?, :to => :call_attempt
  delegate :caller_available?, :to => :call_attempt
  
  include CallCenter
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :incoming_call, :to => :connected , :if => :answered_by_human? && :caller_available?
        event :incoming_call, :to => :abandoned , :if => :answered_by_human? && :caller_not_available?
        event :incoming_call, :to => :call_answered_by_machine , :if => :answered_by_machine?
      end 
      
      state :connected do
        before(:always) { connect_call }
        event :put_in_conference, :to => :in_conference
        event :end, :to => :fail
      end
      
      state :abandoned do
        before(:always) {abandon_call}
        # response do hangup
      end
      
      state :call_answered_by_machine do
        before(:always) { call_answered_by_machine }
      end
      
      state :in_conference do
        event :disconnect, :to => :disconnected
      end
      
      state :disconnected do
        before(:always) { disconnected }
        event :end, :to => :success
      end
      
      state :ended do
        before(:always) { ended }
        event :voter_response, :to => :wrapped_up
      end
      
      
      
      # render(:abandon_call)  do  |call, x| 
      #   x.Hangup 
      # end
      
      # on_render(:ended) { |call, x| x.Hangup }
      #             
  end 
  
  def run(event)
      send(event)
      render
  end
  
  def answered_by_machine?
    answered_by == "machine"
  end
  
  def answered_by_human?
    answered_by == "human"
  end
  
  
end  