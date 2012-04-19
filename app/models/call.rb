class Call < ActiveRecord::Base
  has_one :call_attempt
  serialize :conference_history, Array
  delegate :connect_call, :to => :call_attempt
  delegate :abandon_call, :to => :call_attempt
  delegate :ended, :to => :call_attempt
  include CallCenter
  
  call_flow :state, :initial => :initial do    
    
      state :initial do
        event :incoming_call, :to => :connected , :if => :answered_by_human?
        event :incoming_call, :to => :call_answered_by_machine , :if => :answered_by_machine?
      end 
      
      state :connected do
        event :put_in_conference, :to => :in_conference
        event :end, :to => :fail
      end
      
      state :in_conference do
        event :disconnect, :to => :disconnected
      end
      
      state :disconnected do
        event :end, :to => :success
      end
      
      state :ended do
        event :voter_response, :to => :wrapped_up
      end
      
      
      
      on_render(:abandon_call, :disconnected) { |call, x| x.Hangup }
      on_render(:ended) { |call, x| x.Hangup }
      
      on_flow_to(:connected) { |call, transition| call.connect_call }
      on_flow_to(:call_answered_by_machine) { |call, transition| call.call_answered_by_machine }
      
      on_flow_to(:abandoned_call) { |call, transition| call.abandon_call }
      
      on_flow_to(:disconnected) {|call, transition| call.disconnected}
      
      on_flow_to(:ended) {|call, transition| call.ended}
            
  end 
  
  def answered_by_machine?
    answered_by == "machine"
  end
  
  def answered_by_human?
    answered_by == "human"
  end
  
  
end  