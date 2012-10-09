require "spec_helper"
require 'timecop'
require Rails.root.join('app/models/redis/redis_call.rb')

describe PersistCalls do

  let!(:campaign) { Factory(:campaign) }
  let!(:voter) { Factory(:voter, campaign: campaign) }
  let!(:call_attempt) { Factory(:call_attempt, voter: voter, campaign: campaign) }
  let!(:call) { Factory(:call, call_attempt: call_attempt) }
  let!(:time) { Time.now.utc.to_s }

  describe ".abandoned_calls" do
    before(:each) do
      @voters = [] 
      @attempts = []
      RedisCall.push_to_abandoned_call_list(call.attributes)
      RedisCall.abandoned_call_list.first['current_time'] = time
      PersistCalls.abandoned_calls(@attempts, @voters)
    end

    it "should return abandoned voters and call attempts" do
      @attempts.should have(1).item
      @voters.should have(1).item
      attempt = @attempts.first
      attempt.status.should == CallAttempt::Status::ABANDONED
      attempt.wrapup_time.should == time
      attempt.connecttime.should == time
      attempt.call_end.should == time
      attempt.wrapup_time.should == time
    end

    context "persisting" do
      before(:each) { PersistCalls.perform }
      it "should save call attempt with proper parameters" do
        p call_attempt.id
        call_attempt.reload.status.should == CallAttempt::Status::ABANDONED
        call_attempt.wrapup_time.should == time
        call_attempt.connecttime.should == time
        call_attempt.call_end.should == time
        call_attempt.wrapup_time.should == time
      end
    end
  end

  it '"should persist data for call_attempts and voters" ' do
    time = Time.now.utc
    Timecop.freeze(time) do
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
