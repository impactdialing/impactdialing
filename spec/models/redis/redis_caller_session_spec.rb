require "spec_helper"

describe RedisCallerSession do
  
  it "should load caller session" do
    caller_session = Factory(:webui_caller_session)
    RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
    RedisCallerSession.read(caller_session.id).should eq({"attempt_in_progress"=>"", "available_for_call"=>"false", 
    "caller_id"=>"", "caller_number"=>"", "caller_type"=>"", "campaign_id"=>"", 
    "created_at"=>"#{Time.now.utc}", "debited"=>"false", "digit"=>"", "endtime"=>"", "id"=>"#{caller_session.id}", 
    "lock_version"=>"0", "on_call"=>"false", "payment_id"=>"", "question_id"=>"", "session_key"=>"", "sid"=>"", 
    "starttime"=>"", "state"=>"initial", "tAccountSid"=>"", "tCallSegmentSid"=>"", "tCalled"=>"", "tCaller"=>"", 
    "tDuration"=>"", "tEndTime"=>"", "tFlags"=>"", "tPhoneNumberSid"=>"", "tPrice"=>"", "tStartTime"=>"", "tStatus"=>"", 
    "type"=>"WebuiCallerSession", "updated_at"=>"#{Time.now.utc}", "voter_in_progress_id"=>""})
  end
  
  it "should read caller id" do
    caller_session = Factory(:webui_caller_session, caller_id: 123)
    RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
    RedisCallerSession.read(caller_session.id)["caller_id"].should eq("123")    
  end
end
