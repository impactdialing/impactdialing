class CallEndJob 
  @queue = :call_end
  
   def self.perform(params)    
     call_id = params['id']
     unless call_id.blank?
       call = Call.find(call_id)
       call.end_unanswered_call(params['call_status'])
     end
   end
end