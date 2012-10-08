require "spec_helper"

describe PersistCalls do
  
  it "should persist data for call_attempts and voters" do
    campaign = Factory(:campaign)
    voter1 = Factory(:voter, campaign: campaign)
    call_attempt1 = Factory(:call_attempt, voter: voter1, campaign: campaign)
    call1 = Factory(:call, call_attempt: call_attempt1)
    voter2 = Factory(:voter, campaign: campaign)
    call_attempt2 = Factory(:call_attempt, voter: voter2, campaign: campaign)
    call2 = Factory(:call, call_attempt: call_attempt2)
    voter3 = Factory(:voter, campaign: campaign)
    call_attempt3 = Factory(:call_attempt, voter: voter3, campaign: campaign)
    call3 = Factory(:call, call_attempt: call_attempt3)

    voter4 = Factory(:voter, campaign: campaign)
    call_attempt4 = Factory(:call_attempt, voter: voter4, campaign: campaign)
    call4 = Factory(:call, call_attempt: call_attempt4)
    
    RedisCall.push_to_abandoned_call_list(call1.attributes)
    RedisCall.push_to_not_answered_call_list(call2.attributes)
    RedisCall.push_to_disconnected_call_list(call3.attributes)
    RedisCall.push_to_wrapped_up_call_list(call_attempt3.attributes)
    RedisCall.push_to_processing_by_machine_call_hash(call4.attributes)
    RedisCall.push_to_end_by_machine_call_list(call4.attributes)
    
    PersistCalls.perform
  end
end