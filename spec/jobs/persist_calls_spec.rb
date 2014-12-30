require "spec_helper"
require Rails.root.join('app/models/redis/redis_call.rb')

describe PersistCalls do

  let!(:recording){ create(:recording) }
  let!(:campaign) { create(:campaign, {recording_id: recording.id}) }
  let!(:voter) { create(:voter, campaign: campaign) }
  let!(:call_attempt) { create(:call_attempt, voter: voter, household: voter.household, campaign: campaign) }
  let!(:call) { create(:call, call_attempt: call_attempt) }
  let!(:time) { Time.zone.now.to_s }
  let!(:new_call_attempt) { create(:call_attempt, voter: voter, household: voter.household, campaign: campaign) }
  let!(:new_call) { create(:call, call_attempt: new_call_attempt) }

  before(:each) do
    Redis.new.flushall
    $redis_call_flow_connection.lpush "abandoned_call_list", {id: call.id, current_time: time}.to_json
    $redis_call_flow_connection.lpush "abandoned_call_list", {id: 123, current_time: Time.zone.now - 1.day}.to_json

    $redis_call_end_connection.lpush "not_answered_call_list" , {id: call.id, call_status: "busy", current_time: time}.to_json

    $redis_call_flow_connection.lpush "disconnected_call_list" , {id: call.id, recording_duration: 15, recording_url: "url", caller_id: 1, current_time: time}.to_json
    $redis_call_flow_connection.lpush "disconnected_call_list" , {id: call.id, recording_duration: 15, recording_url: "url", caller_id: 1, current_time: time}.to_json
    $redis_call_flow_connection.lpush "disconnected_call_list" , {id: new_call.id, recording_duration: 15, recording_url: "url", caller_id: 3, current_time: time}.to_json

    $redis_call_flow_connection.lpush "wrapped_up_call_list" , {id: call_attempt.id, voter_id: voter.id, caller_type: CallerSession::CallerType::TWILIO_CLIENT, current_time: time}.to_json

    $redis_call_flow_connection.lpush "end_answered_by_machine_call_list" , {id: call.id, current_time: time}.to_json
  end

  describe ".perform" do

    context "data in redis" do

      context "success" do
        before(:each) { PersistCalls.perform }
        it "should remove data from all redis lists" do
          expect($redis_call_flow_connection.llen("abandoned_call_list")).to eq(0)
          expect($redis_call_end_connection.llen("not_answered_call_list")).to eq(0)
          expect($redis_call_flow_connection.llen("disconnected_call_list")).to eq(0)
          expect($redis_call_flow_connection.llen("wrapped_up_call_list")).to eq(0)
          expect($redis_call_flow_connection.llen("end_answered_by_machine_call_list")).to eq(0)
        end
      end

      context "exception" do
        before(:each) do
          allow(Call).to receive(:where) { raise 'exception' }
          allow(CallAttempt).to receive(:where) { raise 'exception' }
          # expect{ PersistCalls.perform }.to raise_error{ 'exception' }
          begin
            PersistCalls.perform
          rescue Exception
          end
        end

        it "should NOT remove data from all redis lists" do
          expect($redis_call_flow_connection.llen("abandoned_call_list")).to eq(2)
          expect($redis_call_end_connection.llen("not_answered_call_list")).to eq(1)
          expect($redis_call_flow_connection.llen("disconnected_call_list")).to eq(3)
          expect($redis_call_flow_connection.llen("wrapped_up_call_list")).to eq(1)
          expect($redis_call_flow_connection.llen("end_answered_by_machine_call_list")).to eq(1)
        end
      end
    end
  end

  describe ".abandoned_calls" do
    before(:each) { PersistCalls.abandoned_calls(100) }

    context "household" do
      subject { voter.household.reload }

      it 'updates household status' do
        expect(subject.status).to eq CallAttempt::Status::ABANDONED
      end
      it 'updates household presented_at' do
        expect(subject.presented_at).to eq time
      end
      it '[legacy] unsets caller session'
      it '[legacy] unsets caller'
    end

    context "call_attempt" do
      subject { call_attempt.reload }

      its(:status) { should == CallAttempt::Status::ABANDONED }
      its(:call_end) { should == time }
      its(:connecttime) { should == time }
    end

  end

  describe ".unanswered_calls" do
    before(:each) { PersistCalls.unanswered_calls(100) }

    context "call_attempt" do
      subject { call_attempt.reload }

      its(:status) { should == CallAttempt::Status::BUSY }
      its(:call_end) { should == time }
      its(:wrapup_time) { should == time }
    end

    context "voter" do
      subject { voter.household.reload }

      its(:status) { should == CallAttempt::Status::BUSY }
    end
  end

  describe ".disconnected" do
    before(:each) { PersistCalls.disconnected_calls(100) }

    context "call_attempt" do
      subject { call_attempt.reload }
      its(:status) { should == CallAttempt::Status::SUCCESS }
      its(:recording_url) { should == "url" }
      its(:recording_duration) { should == 15 }
      its(:caller_id) { should == 1 }
    end

    context "new_call_attempt" do
      subject { new_call_attempt.reload }
      its(:status) { should == CallAttempt::Status::SUCCESS }
      its(:recording_url) { should == "url" }
      its(:recording_duration) { should == 15 }
      its(:caller_id) { should == 3 }
    end

    context "household" do
      subject{ voter.household.reload }
      its(:status){ should == CallAttempt::Status::SUCCESS }
      its(:presented_at){ should == time }
    end
  end

  context ".wrappedup" do
    before(:each) { PersistCalls.perform }

    context "call_attempt" do
      subject { call_attempt.reload }
      its(:wrapup_time) { should == time }
    end

    context "voter" do
      subject { voter.reload }
      its(:status) { should == CallAttempt::Status::SUCCESS }
      its(:caller_id) { should == 1 }
    end
  end

  context ".endbymachine" do
    context "no message was drop" do
      before(:each) do
        RedisCallFlow.processing_by_machine_call_hash.store(call.id, time)
        PersistCalls.machine_calls(100)
      end
      context "call_attempt" do
        subject { call_attempt.reload }
        its(:status) { should == CallAttempt::Status::HANGUP }
        its(:connecttime) { should == time }
        its(:call_end) { should == time }
        its(:wrapup_time) { should == time }
      end
      context 'household' do
        subject { voter.household.reload }
        its(:status) { should == CallAttempt::Status::HANGUP }
      end
    end

    context 'message was dropped' do
      before do
        RedisCallFlow.record_message_drop_info(call.id, campaign.recording_id, 'automatic')
        RedisCallFlow.processing_by_machine_call_hash.store(call.id, time)
        PersistCalls.machine_calls(100)
      end

      context 'household' do
        subject{ voter.household.reload }

        it 'updates status to CallAttempt::Status::VOICEMAIL' do
          expect(subject.status).to eq CallAttempt::Status::VOICEMAIL
        end
      end
    end
  end
end
