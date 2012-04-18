desc "Daily cleanup of unwrapped calls and ringing ,lines"

task :clean_up => :environment do
  CallAttempt.not_wrapped_up.each {|x| x.update_attributes(wrapup_time: Time.now)}
  CallAttempt.with_status(CallAttempt::Status::RINGING).each {|x| x.update_attributes(status: 'not called')}
  CallAttempt.with_status(CallAttempt::Status::INPROGRESS).each {|x| x.update_attributes(status: 'not called')}
  CallAttempt.with_status(CallAttempt::Status::READY).each {|x| x.update_attributes(status: 'not called')}
  
  Voter.by_status(CallAttempt::Status::RINGING).each {|x| x.update_attributes(status: 'not called')}
  Voter.by_status(CallAttempt::Status::INPROGRESS).each {|x| x.update_attributes(status: 'not called')}
  Voter.by_status(CallAttempt::Status::READY).each {|x| x.update_attributes(status: 'not called')}
  Voter.where("caller_session_id is not null").each {|x| x.update_attributes(caller_session_id: nil)}
  
  Moderator.active.each {|x| x.update_attributes(active: false)}
end
