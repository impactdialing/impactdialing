class CallEndJob 
  @queue = :call_end
  
   def self.perform(params)    
     call_id = params['id']
     unless call_id.blank?
       call = Call.find(call_id)
       call.end_unanswered_call(params['call_status']) if ["no-answer", "busy", "failed"].include?(params['call_status'])
       call.end_answered_by_machine if params['answered_by'] == "machine"
     end
   end
end