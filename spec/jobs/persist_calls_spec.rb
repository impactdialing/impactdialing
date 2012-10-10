require "spec_helper"
require Rails.root.join('app/models/redis/redis_call.rb')

describe PersistCalls do

  let!(:campaign) { Factory(:campaign) }
  let!(:voter) { Factory(:voter, campaign: campaign) }
  let!(:call_attempt) { Factory(:call_attempt, voter: voter, campaign: campaign) }
  let!(:call) { Factory(:call, call_attempt: call_attempt) }
  let!(:time) { Time.now.to_s }

  context ".abandoned_calls" do
    before(:each) do
      $redis_call_flow_connection.lpush "abandoned_call_list", {id: call.id, current_time: time}.to_json
      PersistCalls.perform
    end

    context "voter" do
      subject { voter.reload }

      its(:status) { should == CallAttempt::Status::ABANDONED }
      its(:call_back) { should be_false }
      its(:caller_session) { should be_nil }
      its(:caller_id) { should be_nil }
    end

    context "call_attempt" do
      subject { call_attempt.reload }

      its(:status) { should == CallAttempt::Status::ABANDONED }
      its(:call_end) { should == time }
      its(:connecttime) { should == time }
    end
  end

  context ".unanswered_calls" do
    before(:each) do
      $redis_call_end_connection.lpush "not_answered_call_list" , {id: call.id, call_status: "busy", current_time: time}.to_json
      PersistCalls.perform
    end

    context "call_attempt" do
      subject { call_attempt.reload }

      its(:status) { should == CallAttempt::Status::BUSY }
      its(:call_end) { should == time }
      its(:wrapup_time) { should == time }
    end

    context "voter" do
      subject { voter.reload }

      its(:status) { should == CallAttempt::Status::BUSY }
      its(:call_back) { should be_false } 
    end
  end
end
