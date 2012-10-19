#! /home/gregolsen/projects/Impact-Dialing/script/rails runner

LIMIT = 20 
CALLER_SESSIONS_STATUSES = %w{
  caller_on_call                           
  campaign_out_of_phone_numbers            
  conference_ended                         
  conference_started_phones_only_predictive
  connected                                
  initial                                  
  paused                                   
  read_choice                              
  read_next_question                       
  ready_to_call                            
  stopped                                  
  subscription_limit                       
  time_period_exceeded                     
  voter_response                           
}
CALL_STATUSES = %w{
  wrapup_and_continue      
  wrapup_and_stop          
  call_answered_by_lead    
  abandoned                
  connected                
  call_not_answered_by_lead
  hungup                   
  initial                  
  disconnected             
  call_answered_by_machine 
}

campaigns = Campaign.reorder('id DESC').limit(LIMIT).pluck(:id)
sessions = CallerSession.reorder('id DESC').limit(LIMIT).pluck(:id)
attempts = CallAttempt.reorder('id DESC').limit(LIMIT).pluck(:id)
calls = Call.reorder('id DESC').limit(LIMIT).pluck(:id)
voters = Voter.reorder('id DESC').limit(LIMIT).pluck(:id)
sqls = []

def transform_relation(relation)
  relation.to_sql + ';'
end

sqls += campaigns.map do |id|
  transform_relation Campaign.where(id: id)
end

sqls += sessions.flat_map do |id|
  [
    transform_relation(CallerSession.where(id: id)),
    "UPDATE caller_sessions set state='#{CALLER_SESSIONS_STATUSES.sample}' where id = #{id};"
  ]
end

sqls += attempts.map do |id|
  transform_relation(CallAttempt.where(id: id))
end

sqls += calls.flat_map do |id|
  [
    transform_relation(Call.where(id: id)),
    "UPDATE calls set state='#{CALL_STATUSES.sample}' where id = #{id};"
  ]
end

sqls += voters.map do |id|
  transform_relation(Voter.where(id: id))
end

sqls *= 10
sqls.shuffle!
puts sqls
