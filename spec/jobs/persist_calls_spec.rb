require "spec_helper"
require 'timecop'

describe PersistCalls do

  it '"should persist data for call_attempts and voters" ' do
    time = Time.now.utc
    Timecop.freeze(time) do
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

      voter1.reload.status.should == CallAttempt::Status::ABANDONED
      call_attempt1.reload.status.should == CallAttempt::Status::ABANDONED

      call_attempt1.reload.connecttime.should == time.to_s
      call_attempt1.reload.call_end.should == time.to_s
      call_attempt1.reload.wrapup_time.should == time.to_s

      voter2.reload.status.should == call2.call_status
      call_attempt2.reload.status.should == call2.call_status

      voter3.reload.status.should == CallAttempt::Status::SUCCESS
      call_attempt3.reload.status.should == CallAttempt::Status::SUCCESS

      voter4.reload.status.should == CallAttempt::Status::HANGUP
      call_attempt4.reload.status.should == CallAttempt::Status::HANGUP

    end
  end
end
