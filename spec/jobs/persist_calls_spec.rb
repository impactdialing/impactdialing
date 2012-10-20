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
  
  context ".disconnected" do
    before(:each) do
      $redis_call_flow_connection.lpush "disconnected_call_list" , {id: call.id, recording_duration: 15, recording_url: "url", caller_id: 1, current_time: time}.to_json
      PersistCalls.perform
    end

    context "call_attempt" do
      subject { call_attempt.reload }
      its(:status) { should == CallAttempt::Status::SUCCESS }
      its(:recording_url) { should == "url" }
      its(:recording_duration) { should == 15 }
      its(:caller_id) { should == 1 }
    end

    context "voter" do
      subject { voter.reload }

      its(:status) { should == CallAttempt::Status::SUCCESS }
      its(:caller_id) { should == 1 }
    end
  end
  
  context ".wrappedup" do
    before(:each) do
      $redis_call_flow_connection.lpush "wrapped_up_call_list" , {id: call_attempt.id, caller_type: CallerSession::CallerType::TWILIO_CLIENT, current_time: time}.to_json
      PersistCalls.perform
    end

    context "call_attempt" do
      subject { call_attempt.reload }
      its(:wrapup_time) { should == time }
    end

  end
  
  context ".endbymachine" do
    before(:each) do
      $redis_call_flow_connection.lpush "end_answered_by_machine_call_list" , {id: call.id, current_time: time}.to_json
      RedisCallFlow.processing_by_machine_call_hash.store(call.id, time)
      PersistCalls.perform
    end

    context "call_attempt" do
      subject { call_attempt.reload }
      its(:status) { should == CallAttempt::Status::HANGUP }
      its(:connecttime) { should == time }
      its(:call_end) { should == time }
      its(:wrapup_time) { should == time }
    end

    context "voter" do
      subject { voter.reload }

      its(:status) { should == CallAttempt::Status::HANGUP }
      its(:call_back) { should == false }
    end
  end
  
  
end
